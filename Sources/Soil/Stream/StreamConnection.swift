
/**
 A connection to a component that transmits and receives encoded messages.
 */
public protocol StreamConnection: Connection, Sendable {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(bytes: [UInt8]) -> Request

    /**
     Set the receiver for encoded messages from this connection.
     - Parameter receiver: The receiver of the encoded messages coming in over this connection.
     */
    func setReceiver(_ receiver: any StreamReceiver) async
}

extension StreamConnection {

    /**
     Convert this stream to an encoded message connection using the provided framing.
     - Parameter framing: The framing to use for encoded messages transmitted over the stream.
     - Returns: The encoded message connection using the framing over the stream.
     */
    public func apply(framing: any StreamFraming) async -> EncodedMessageConnection {
        await DecodedStream(wrapping: self, framing: framing)
    }
}
