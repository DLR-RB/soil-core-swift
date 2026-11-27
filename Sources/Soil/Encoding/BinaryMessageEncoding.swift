import Foundation

/**
 An encoding that represents messages in a compact binary format.

 All messages use the same layout:

 `HEADER | [ID] | [COUNT] | [DEPTH] | [TIME] | [END] | PATH | [TREE]`

 The header byte contains the message type in the three most significant bits,
 followed by one flag bit for each of the optional fields `ID`, `COUNT`, `DEPTH`, `TIME` and `END`.
 The `ID` is a varint of the bit pattern, `COUNT` and `DEPTH` are varints (negative values are encoded as zero),
 and `TIME` and `END` are big endian doubles of the seconds since 1970.
 Only data messages contain a `TREE`, where the `TIME` is the timestamp of the message, not of a sample.
 All header fields are encoded if present, and decoded, for every message type, even if the type doesn't use them.

 A tree node starts with a byte containing the number of children (upper four bits) and samples (lower four bits).
 Counts of 15 or more are indicated by `0b1111`, and the total count follows as a varint (children first).
 The samples follow, and then the children, each as the name (a string) followed by the child tree.

 A sample starts with a byte containing a flag for the timestamp (most significant bit) and the value type (lower seven bits),
 followed by the optional timestamp as a big endian double, and the content of the value.

 Values, strings and varints are encoded as described in ``BinaryValueEncoding``.
 */
public final class BinaryMessageEncoding: Sendable {

    /// Create a binary encoding layer.
    public init() {

    }
}

extension BinaryMessageEncoding: MessageEncoding {

    /**
     Convert a message to binary data for transmission.
     - Parameter message: The message to encode
     - Returns: The binary data of the encoded message
     - Throws: `EncodingError.invalidValue`, if a timestamp is not finite
     */
    public func encode(_ message: Message) throws -> Data {
        var writer = BinaryWriter()
        try writer.write(message)
        return Data(writer.bytes)
    }

    /**
     Extract a message from binary data.
     - Parameter data: The encoded message
     - Returns: The decoded message
     - Throws: `DecodingError.dataCorrupted`, if the data is not a valid message
     */
    public func decode(_ data: Data) throws -> Message {
        try data.withUnsafeBytes { bytes in
            var reader = BinaryReader(bytes: bytes)
            let message = try reader.readMessage()
            guard reader.isAtEnd else {
                throw reader.error("Unexpected bytes after encoded message")
            }
            return message
        }
    }
}

extension MessageType {

    /// The type code used by ``BinaryMessageEncoding``
    var binaryCode: UInt8 {
        switch self {
        case .data: 0
        case .request: 1
        case .deletionRequest: 2
        case .subscriptionInclusion: 3
        case .subscriptionExclusion: 4
        case .subscriptionDeletion: 5
        }
    }

    init?(binaryCode: UInt8) {
        switch binaryCode {
        case 0: self = .data
        case 1: self = .request
        case 2: self = .deletionRequest
        case 3: self = .subscriptionInclusion
        case 4: self = .subscriptionExclusion
        case 5: self = .subscriptionDeletion
        default: return nil
        }
    }
}

/// The bits of the message header byte
private enum HeaderFlag {
    static let typeShift: UInt8 = 5
    static let id: UInt8 = 0b0001_0000
    static let count: UInt8 = 0b0000_1000
    static let depth: UInt8 = 0b0000_0100
    static let time: UInt8 = 0b0000_0010
    static let end: UInt8 = 0b0000_0001
}

/// The marker for counts in a tree node header that are followed by the total count
private let extendedTreeCount: UInt8 = 0b1111

/// The flag in the first byte of a sample, indicating that a timestamp follows
private let sampleTimestampFlag: UInt8 = 0b1000_0000

// MARK: Encoding

extension BinaryWriter {

    fileprivate mutating func write(_ message: Message) throws {
        var header = message.type.binaryCode << HeaderFlag.typeShift
        if message.id != nil { header |= HeaderFlag.id }
        if message.count != nil { header |= HeaderFlag.count }
        if message.depth != nil { header |= HeaderFlag.depth }
        if message.time != nil { header |= HeaderFlag.time }
        if message.end != nil { header |= HeaderFlag.end }
        bytes.append(header)

        if let id = message.id {
            write(varint: UInt64(bitPattern: Int64(id)))
        }
        // Negative values are treated as zero
        if let count = message.count {
            write(count: max(0, count))
        }
        if let depth = message.depth {
            write(count: max(0, depth))
        }
        if let time = message.time {
            try write(timestamp: time)
        }
        if let end = message.end {
            try write(timestamp: end)
        }
        write(message.path)
        // Only data messages contain data
        if message.type == .data {
            try write(message.data)
        }
    }

    private mutating func write(timestamp: Timestamp) throws {
        let value = timestamp.timeIntervalSince1970
        guard value.isFinite else {
            throw EncodingError.invalidValue(timestamp, .init(codingPath: [], debugDescription: "Unable to encode non-finite timestamp \(value)"))
        }
        write(value)
    }

    private mutating func write(_ tree: any SampleTree) throws {
        let samples = tree.samples
        let children = tree.children
        let childCount = UInt8(min(children.count, Int(extendedTreeCount)))
        let sampleCount = UInt8(min(samples.count, Int(extendedTreeCount)))
        bytes.append(childCount << 4 | sampleCount)
        if childCount == extendedTreeCount {
            write(count: children.count)
        }
        if sampleCount == extendedTreeCount {
            write(count: samples.count)
        }
        for sample in samples {
            try write(sample)
        }
        // Sort names for a deterministic encoding
        for name in children.keys.sorted() {
            write(name)
            try write(children[name]!)
        }
    }

    private mutating func write(_ sample: Sample) throws {
        let type = sample.value.type.binaryCode
        guard let timestamp = sample.timestamp else {
            bytes.append(type)
            writeContent(of: sample.value)
            return
        }
        bytes.append(sampleTimestampFlag | type)
        try write(timestamp: timestamp)
        writeContent(of: sample.value)
    }
}

// MARK: Decoding

extension BinaryReader {

    fileprivate mutating func readMessage() throws -> Message {
        let header = try readByte()
        let code = header >> HeaderFlag.typeShift
        guard let type = MessageType(binaryCode: code) else {
            throw error("Unknown message type \(code)")
        }
        let id = header & HeaderFlag.id != 0 ? Int(truncatingIfNeeded: Int64(bitPattern: try readVarint())) : nil
        let count = header & HeaderFlag.count != 0 ? try readClampedCount() : nil
        let depth = header & HeaderFlag.depth != 0 ? try readClampedCount() : nil
        let time = header & HeaderFlag.time != 0 ? try readTimestamp() : nil
        let end = header & HeaderFlag.end != 0 ? try readTimestamp() : nil
        let path = try readPath()
        let data = type == .data ? try readTree() : ImmutableSampleTree.empty
        return Message(type: type, path: path, time: time, data: data, count: count, depth: depth, end: end, id: id)
    }

    /// Read a count or depth, where values outside of the range of `Int` are clamped to `Int.max`
    private mutating func readClampedCount() throws -> Int {
        Int(clamping: try readVarint())
    }

    private mutating func readTimestamp() throws -> Timestamp {
        let value = try readDouble()
        guard value.isFinite else {
            throw error("Invalid timestamp \(value)")
        }
        return Timestamp(timeIntervalSince1970: value)
    }

    private mutating func readTree() throws -> ImmutableSampleTree {
        try enterNested()
        let header = try readByte()
        var childCount = Int(header >> 4)
        var sampleCount = Int(header & 0b1111)
        if childCount == extendedTreeCount {
            childCount = try readCount()
        }
        if sampleCount == extendedTreeCount {
            sampleCount = try readCount()
        }
        var samples: [Sample] = []
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            samples.append(try readSample())
        }
        var children: [PathComponent : any SampleTree] = [:]
        children.reserveCapacity(childCount)
        for _ in 0..<childCount {
            // If a name appears multiple times, then the last child is used
            let name = try readString()
            children[name] = try readTree()
        }
        leaveNested()
        return ImmutableSampleTree(samples: samples, children: children)
    }

    private mutating func readSample() throws -> Sample {
        let header = try readByte()
        let code = header & ~sampleTimestampFlag
        guard let type = ValueType(binaryCode: code) else {
            throw unknownValueType(code)
        }
        let timestamp = header & sampleTimestampFlag != 0 ? try readTimestamp() : nil
        return Sample(value: try readContent(as: type), timestamp: timestamp)
    }
}
