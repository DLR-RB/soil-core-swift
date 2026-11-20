
/**
 A connection to a component that transmits and receives frames.
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
     Convert this stream to a frame connection using the provided framing.
     - Parameter framing: The framing to use for frames transmitted over the stream.
     - Parameter logger: The logger for encoding errors
     - Returns: The frame connection using the framing over the stream.
     */
    public func apply(framing: any StreamFraming, logger: (any Logger)? = nil) async -> any FrameConnection {
        await DecodedStream(wrapping: self, framing: framing, logger: logger)
    }

    /**
     Convert this raw stream into a message connection using both the provided framing and encoding.

     This is a convenience that combines [`apply(framing:)`](#L25) and [`apply(encoding:)`](Sources/Soil/Framing/FrameConnection.swift#L26): first the byte stream is split into frames, then those frames are decoded into messages.
     - Parameter framing: The framing to use for frames transmitted over the stream.
     - Parameter encoding: The encoding to use for messages over the frames.
     - Parameter logger: The logger for encoding and framing errors
     - Returns: The message connection using the framing and encoding over the stream.
     */
    public func apply(framing: any StreamFraming, encoding: any MessageEncoding, logger: (any Logger)? = nil) async -> any MessageConnection {
        let frames = await self.apply(framing: framing, logger: logger)
        return await frames.apply(encoding: encoding, logger: logger)
    }
}
