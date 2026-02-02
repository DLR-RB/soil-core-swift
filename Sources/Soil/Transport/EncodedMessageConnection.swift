import Foundation

/**
 A connection to a component that transmits and receives encoded messages.
 */
public protocol EncodedMessageConnection: Sendable {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(message: Data) -> Request

    /**
     Set the receiver for encoded messages from this connection.
     - Parameter receiver: The receiver of the encoded messages coming in over this connection.
     */
    func setReceiver(_ receiver: EncodedMessageReceiver) async
}
