
/**
 A connection to a component that transmits and receives encoded messages.
 */
public protocol StreamConnection: Connection, StreamDistributor, Sendable {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(bytes: [UInt8]) -> any Request
}

extension StreamConnection {

    /**
     Convert this stream to an encoded message connection using the provided framing.
     - Parameter framing: The framing to use for encoded messages transmitted over the stream.
     - Parameter logger: The logger for encoding errors
     - Returns: The encoded message connection using the framing over the stream.
     */
    public func apply(framing: any StreamFraming, logger: (any Logger)? = nil) async -> EncodedMessageConnection {
        await DecodedStream(wrapping: self, framing: framing, logger: logger)
    }
}
