
/**
 A connection to a component via a transport layer
 */
public protocol MessageConnection: Sendable {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(message: Message) -> Request

    /**
     Set the receiver for messages produced by this connection.
     - Parameter receiver: The receiver of the messages coming in over this connection.
     */
    func setReceiver(_ receiver: MessageReceiver) async
}


extension MessageConnection {

    /**
     Send samples in a tree over the connection.
     - Parameter tree: The tree to send
     - Parameter path: The path associated with the tree
     - Note: Each node with samples in the tree is sent as a separate message
     */
    @discardableResult
    func send(_ tree: SampleTree, for path: Path) -> Request {
        AsyncRequest {
            await self.send(tree, for: path)
        }
    }

    /**
     Send samples in a tree over the connection and wait for each message to be sent
     - Parameter tree: The tree to send
     - Parameter path: The path associated with the tree
     - Note: Each node with samples in the tree is sent as a separate message
     */
    private func send(_ tree: SampleTree, for path: Path) async {
        if !tree.samples.isEmpty {
            await send(tree.samples, for: path)
        }
        // Recurse into sub-trees to send all changes
        for (childPath, child) in tree.children {
            await send(child, for: path + [childPath])
        }
    }

    /**
     Send all samples of a node as a single message.
     - Parameter samples: The samples to send
     - Parameter path: The path associated with the samples.
     */
    private func send(_ samples: [Sample], for path: Path) async {
        await send(message: .samples(samples, for: path)).wait()
    }
}