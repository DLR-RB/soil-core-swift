
/**
 A connection to a component via a transport layer
 */
public protocol MessageConnection: Receiver, Connection, MessageDistributor, Sendable {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(message: Message) -> any Request
}

// MARK: Receiver

extension MessageConnection {

    /**
     Send a tree over the connection.
     - Parameter tree: The tree to send for the path.
     - Parameter path: The path associated with the tree
     - Returns: A request handle, to optionally wait until the data is transmitted.
     - Note: This function is not marked `async`, because it is viewed as a request to send data.
       The data does not actually need to be sent when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    public func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        send(message: .tree(tree, for: path))
    }
}
