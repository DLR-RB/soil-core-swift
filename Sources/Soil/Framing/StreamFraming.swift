
/**
 A type that provides framing for binary data streams.
 */
public protocol StreamFraming: Sendable {

    /**
     Add framing information to an encode message,
     to make it suitable for transmission over a binary stream.
     - Parameter message: The frame
     - Returns: The frame with framing information added
     - Throws: An error, if the framing information could not be added
     */
    func encodeForStream(_ message: [UInt8]) async throws -> [UInt8]

    /**
     Extract frames from binary stream data.
     - Parameter data: The new data from the binary stream
     - Returns: The messages that could be decoded with the new input
     - Throws: An error, if the frame decoding fails
     */
    func processStreamBytes(_ data: [UInt8]) async -> [[UInt8]]
}
