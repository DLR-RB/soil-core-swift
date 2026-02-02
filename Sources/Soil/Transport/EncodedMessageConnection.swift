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

extension EncodedMessageConnection {

    /**
     Convert this connection to a message connection using the provided encoding
     - Parameter encoding: The encoding to use for messages over the connection.
     - Returns: The message connection using the encoding over the binary connection.
     */
    public func apply(encoding: MessageEncoding) async -> MessageConnection {
        await DecodedConnection(wrapping: self, encoding: encoding)
    }
}