
/**
 Expose a storage over a transport interface.
 */
public actor StorageServer {

    let storage: any Storage

    let transport: any ComponentTransport

    public init(storage: any Storage, transport: any ComponentTransport) {
        self.storage = storage
        self.transport = transport

        // Register to receive messages from the component
        transport.onReceive { [weak self] message in
            if let self {
                Task {
                    await self.didReceive(message: message)
                }
            }
        }
    }

    /**
     Send a message to the component.
     - Parameter message: The message to send.
     - Note: If no message callback is available, then the message is discarded.
     - Returns: `true` if the message was handed to the transport layer.
     */
    @discardableResult
    private func send(_ message: Message) -> Bool {
        transport.send(message: message)
    }

    // MARK: Response handling

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
        await request.wait()
        send(.acknowledge(id, to: message.path))
    }

    private func didReceive(request message: Message) async {
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

    private func didReceive(deletion message: Message) async {
        // Schedule the deletion
        let request = storage.delete(path: message.path, from: message.time, to: message.end, depth: message.depth)

        // Check if the request expects a response
        guard let requestId = message.id else {
            return
        }
        // Wait for the delete to complete
        await request.wait()
        send(.acknowledge(requestId, to: message.path))
    }
}