import Foundation

/**
 A connection to a component that transmits and receives encoded messages.
 */
public protocol BinaryConnection {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(message: Data) -> Request

    /**
     Register a callback to receive messages from the component
     - Parameter callback: The closure called with new messages.
     */
    func onReceive(_ callback: @escaping @Sendable (Data) -> Void)
}
