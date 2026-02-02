
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
