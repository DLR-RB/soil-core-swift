import Foundation

/**
 A frame encoding that uses sync bytes and a 2-byte length indicator to package messages in frames.
 - Note: The maximum message size is 65.535 bytes, which is the largest value fitting into the 2-byte length indicator.
 */
public actor SyncByteLengthFraming {

    /// The bytes to use to identify the start of a frame
    public let syncBytes: [UInt8]

    /// The maximum number of bytes allowed for messages
    public let maxPayloadLength: Int

    /// The ring buffer to store the
    private let ring: ByteRingBuffer

    /// The size of the complete header (sync bytes +  2 length bytes)
    private let headerSize: Int

    // MARK: - Init

    /**
     Create a framing processor.

     The size of the buffer will be chosen two fit two complete frames, plus 1 byte.
     - Parameter syncBytes: The sync bytes used for the frames
     - Parameter maxPayloadLength: The maximum length of a message in the frame (0 < length < 65.536)
     */
    public init(
        syncBytes: [UInt8] = [0xAA, 0x55],
        maxPayloadLength: Int = 65_535
    ) {
        precondition(!syncBytes.isEmpty)
        precondition(maxPayloadLength > 0)
        precondition(maxPayloadLength <= 65_535)

        self.syncBytes = syncBytes
        self.headerSize = syncBytes.count + 2
        self.maxPayloadLength = maxPayloadLength

        // Ensure that the buffer can hold two complete messages
        let ringBufferSize = (maxPayloadLength + syncBytes.count + 2) * 2 + 1
        self.ring = ByteRingBuffer(capacity: ringBufferSize)
    }

    /// The number of bytes currently in the receive buffer
    public var bufferedBytes: Int {
        ring.count
    }
}

// MARK: StreamEncoding

extension SyncByteLengthFraming: StreamFraming {

    /**
     Add framing information (sync bytes and length) to an encoded message,
     to make it suitable for transmission over a binary stream.
     - Parameter message: The encoded message
     - Returns: The encoded message with framing information added
     - Throws: An error, if the framing information could not be added
     */
    public func encodeForStream(_ message: [UInt8]) throws -> [UInt8] {
        guard message.count <= maxPayloadLength else {
            throw FramingError.payloadTooLarge
        }

        let length = UInt16(message.count)
        let lengthData = [UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        return syncBytes + lengthData + message
    }

    /**
     Extract frames with encoded messages from binary stream data.

     The function first searches for the presence of the sync bytes,
     then decodes the following bytes as the length, and then
     extracts the message.
     - Parameter data: The new data from the binary stream
     - Returns: The messages that could be decoded with the new input
     - Throws: An error, if the frame decoding fails
     */
    public func processStreamBytes(_ data: [UInt8]) -> [[UInt8]] {
        // TODO: Insert data in chunks that fit into the buffer,
        // to prevent overflow if provided data is too large.
        ring.write(contentsOf: data)

        var messages: [[UInt8]] = []

        // TODO: Introduce decoding state
        // to not decode sync and length every time a byte comes in

        while true {
            // Need header
            if ring.count < headerSize {
                break
            }

            // Find sync
            guard let syncOffset = ring.findSequence(syncBytes) else {
                // No sync bytes in the buffer, discard all bytes
                ring.clear()
                break
            }

            // Drop bytes before sync
            if syncOffset > 0 {
                ring.discard(syncOffset)
            }

            if ring.count < headerSize {
                break
            }

            // Parse length
            let msb = UInt16(ring.peek(at: syncBytes.count))
            let lsb = UInt16(ring.peek(at: syncBytes.count + 1))
            let length = Int((msb << 8) | lsb)

            if length > maxPayloadLength {
                ring.discard(1)
                continue
            }

            // Check that full message is present
            if ring.count < headerSize + length {
                break
            }

            // Skip header
            ring.discard(headerSize)

            // Read payload
            let payload = ring.read(length)

            messages.append(payload)
        }

        return messages
    }
}
