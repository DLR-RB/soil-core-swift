
/**
 A connection to a component via a transport layer
 */
public protocol MessageConnection: Receiver, Connection, Sendable {

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

// MARK: Receiver

extension MessageConnection {

    /**
     Send samples over the connection.
     - Parameter samples: The samples to send for the path.
     - Parameter path: The path associated with the samples
     - Returns: A request handle, to optionally wait until the data is transmitted.
     - Note: This function is not marked `async`, because it is viewed as a request to send data.
       The data does not actually need to be sent when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    public func receive(_ samples: [Sample], for path: Path) -> any Request {
        send(message: .samples(samples, for: path))
    }
}
