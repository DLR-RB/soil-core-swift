import Foundation

/**
 Apply framing to a binary stream connection to create an encoded message connection.
 */
public actor DecodedStream {

    /// The framing to apply to the stream
    private let framing: any StreamFraming

    /// The binary stream over which data is exchanged
    private let stream: StreamConnection

    /// The receiver getting decoded messages
    private weak var receiver: (any EncodedMessageReceiver)?

    /// The logger to receive encoding errors
    private var log: (any Logger)?

    /**
     Wrap a binary stream with framing.
     - Parameter stream: The binary stream to apply the framing to
     - Parameter encoding: The framing used for the stream
     - Parameter logger: The logger for encoding errors
     */
    public init(wrapping stream: any StreamConnection, framing: any StreamFraming, logger: (any Logger)? = nil) async {
        self.framing = framing
        self.stream = stream
        self.log = logger

        await stream.setReceiver(self)
    }

    /**
     Send a message (actor-isolated) over the connection.

     Attempts to encode the message using the encoding layer, and forwards it over the data connection.
     - Parameter message: The message to transmit
     */
    private func send(_ message: Data) async {
        let bytes: [UInt8]
        do {
            bytes = try await framing.encodeForStream(Array(message))
        } catch {
            log?.error("Failed to decode from stream: \(error)")
            return
        }
        await stream.send(bytes: bytes).wait()
    }
}

extension DecodedStream: StreamReceiver {

     /**
     Process received bytes from the stream.

     Each call to this function can contain an arbitrary number of bytes.
     - Parameter bytes: The received bytes to process
     */
    public func didReceive(bytes: [UInt8]) async {
        let messages = await framing.processStreamBytes(bytes)
        if messages.isEmpty {
            return
        }
        guard let receiver else {
            return
        }
        for message in messages {
            await receiver.didReceive(encodedMessage: Data(message))
        }
    }
}

extension DecodedStream: EncodedMessageConnection {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    public nonisolated func send(message: Data) -> Request {
        AsyncRequest {
            await self.send(message)
        }
    }

    /**
     Set the receiver for messages produced by this connection.
     - Parameter receiver: The receiver of the messages coming in over this connection.
     */
    public func setReceiver(_ receiver: any EncodedMessageReceiver) {
        self.receiver = receiver
    }
}

extension DecodedStream: Connection {

    public func isOpen() async -> Bool {
        await stream.isOpen()
    }

    @discardableResult
    public nonisolated func close() -> Request {
        stream.close()
    }

    public func onClose(perform block: @escaping @Sendable () -> Void) async {
        await stream.onClose(perform: block)
    }
}