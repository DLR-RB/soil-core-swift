
/**
 Expose a storage over a transport interface.

 The class can be used to provide access to a storage interface via a remote connection.
 Request messages received over the connection are processed, and the requested data is returned.
 Data received over the connection is inserted into the provided storage.
 Deletion requests are also executed.
 */
public actor HostedStorage {

    /// The storage that is exposed over the connection
    private let storage: any Storage

    /// The connection over which the storage is hosted
    private let connection: any MessageConnection

    /**
     Create a hosted storage.
     - Parameter storage: The storage to expose
     - Parameter connection: The connection over which the storage should be accessible.
     */
    public init(storage: any Storage, connection: any MessageConnection) async {
        self.storage = storage
        self.connection = connection

        // Register to receive messages from the component
        await connection.setReceiver(self)
    }

    /**
     Send a message to the component.
     - Parameter message: The message to send.
     - Note: If no message callback is available, then the message is discarded.
     - Returns: The request to send the message
     */
    @discardableResult
    private func send(_ message: Message) -> any Request {
        connection.send(message: message)
    }

    // MARK: Response handling

    /**
     The central point where all received messages are processed.
     - Parameter message: The message received over the connection.
     */
    public func didReceive(message: Message) async {
        switch message.type {
        case .data:
            await didReceive(data: message)
        case .request:
            await didReceive(request: message)
        case .deletionRequest:
            await didReceive(deletion: message)
        case .subscriptionInclusion, .subscriptionDeletion, .subscriptionExclusion:
            break
        }
    }

    /**
     Process a data message, by checking which request it matches
     - Parameter message: The received data message
     */
    private func didReceive(data message: Message) async {
        // Note: We know that the message is a data message
        let samples = message.allSamples
        guard !samples.isEmpty else {
            return
        }
        // Schedule the insert
        let request = storage.receive(samples, for: message.path)

        // Check if the request expects a response
        guard let id = message.id else {
            return
        }
        // Wait for the insert to complete and send an acknowledgement
        // TODO: Dispatch to the background to not block other requests from being processed?
        await request.wait()
        send(.acknowledge(id, to: message.path))
    }

    /**
     Processing point for all data requests.
     - Parameter message: The data request
     */
    private func didReceive(request message: Message) async {
        // TODO: Schedule this on another thread to not block other requests in the meantime?
        let tree = await storage.tree(
            for: message.path,
            from: message.time,
            to: message.end,
            depth: message.depth,
            limitPerNode: message.count)

        guard let id = message.id else {
            send(tree: tree, path: message.path, request: nil, count: nil)
            return
        }

        let count = tree.numberOfNodesWithSamples
        guard count > 0 else {
            // Send at least one message if a request id is present
            send(.samples([], for: message.path, inResponseTo: id, totalMessages: 1))
            return
        }

        send(tree: tree, path: message.path, request: id, count: count)
    }

    /**
     Send the contents of a tree as individual data messages per node.
     - Parameter tree: The tree to send
     - Parameter path: The path of the tree root in the data model
     - Parameter request: The id to include in the response
     - Parameter count: The total number of messages to be indicated in each message.
     */
    private func send(tree: SampleTree, path: Path, request: Int?, count: Int?) {
        if !tree.samples.isEmpty {
            // TODO: Should we send an empty message for existing tree nodes without a value?
            // If we change this, then the `count` needs to be adjusted as well.
            let message = Message.samples(tree.samples, for: path, inResponseTo: request, totalMessages: count)
            send(message)
        }
        // Recurse into sub-trees, but keep the total count
        for (childPath, child) in tree.children {
            send(tree: child, path: path + [childPath], request: request, count: count)
        }
    }

    /**
     The central point to process deletion requests received over the connection.
     - Parameter message: The deletion request message received over the connection.
     - Note: This function waits for the deletion to be completed and then sends an acknowledgement
     */
    private func didReceive(deletion message: Message) async {
        // Schedule the deletion
        let request = storage.delete(path: message.path, from: message.time, to: message.end, depth: message.depth)

        // Check if the request expects a response
        guard let requestId = message.id else {
            return
        }
        // Wait for the delete to complete
        // TODO: Dispatch to the background to not block other requests from being processed?
        await request.wait()
        send(.acknowledge(requestId, to: message.path))
    }
}

extension HostedStorage: MessageReceiver {

}