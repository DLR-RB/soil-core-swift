
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
     Register a callback to receive messages from the component
     - Parameter callback: The closure called with new messages.
     */
    func onReceive(_ callback: @escaping @Sendable (Message) -> Void)
}