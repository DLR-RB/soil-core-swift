
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
    public let connection: any MessageConnection

    /**
     Create a hosted storage.
     - Parameter storage: The storage to expose
     - Parameter connection: The connection over which the storage should be accessible.
     */
    public init(hosting storage: any Storage, through connection: any MessageConnection) async {
        self.storage = storage
        self.connection = connection

        // Register to receive messages from the component
        await connection.setReceiver(self).wait()
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
     Process a data message, by checking which request it matches
     - Parameter message: The received data message
     */
    private func didReceive(data message: Message) async {
        // Note: We know that the message is a data message
        // Schedule the insert
        let request = storage.accept(message.data, for: message.path)

        // Always wait for the insert to complete, even if no acknowledgement is needed,
        // so that subsequent messages (e.g. reads) can't overtake the insertion.
        await request.wait()

        // Check if the request expects a response
        guard let id = message.id else {
            return
        }
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
    private func send(tree: any SampleTree, path: Path, request: Int?, count: Int?) {
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

        // Always wait for the delete to complete, even if no acknowledgement is needed,
        // so that subsequent messages (e.g. reads) can't overtake the deletion.
        await request.wait()

        // Check if the request expects a response
        guard let requestId = message.id else {
            return
        }
        send(.acknowledge(requestId, to: message.path))
    }
}

// MARK: Receiver

extension HostedStorage: MessageReceiver {

    /**
     The central point where all received messages are processed.
     - Parameter message: The message received over the connection.
     - Note: This function is called automatically by the connection, and should not be called manually.
     */
    @discardableResult
    public nonisolated func accept(message: Message) -> any Request {
        AsyncRequest {
            await self.didReceive(message: message)
        }
    }

    private func didReceive(message: Message) async {
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
}

// MARK: Storage

extension HostedStorage: Storage {

    /**
     Receive a request to store a tree for a path.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the data is stored, use ``commit()``
     - SeeAlso: ``commit(_:for:)``
     */
    @discardableResult
    public nonisolated func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        storage.accept(tree, for: path)
    }

    /**
     Read a data tree for a given path within a given interval.

     This is the singular function to serve all data retrieval needs.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     The `limitPerNode` is applied in sort order.

     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels below the path to include in the result
     - Parameter limitPerNode: The maximum number of values to return for each node of the tree (defaults to `nil`, e.g. no limit)
     - Returns: The tree with the given depth, limited to the maximum count per node, for the requested interval.
     - Note: This function is `async`, because providing the data may take some time.
       It could be retrieved over a network, from an otherwise slow database, or from other components.
     */
    public func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) async -> any SampleTree {
        await storage.tree(for: path, from: start, to: end, depth: depth, limitPerNode: limitPerNode)
    }

    /**
     Delete data from the storage.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Returns: A request that can be used to wait until completion
     */
    @discardableResult
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        storage.delete(path: path, from: start, to: end, depth: depth)
    }
}
