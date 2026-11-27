import Foundation

/**
 Encodes values in a compact binary format.

 The encoding doesn't use `Codable`, which makes it faster and smaller than general purpose encoders.

 A tagged value consists of the type code (one byte), followed by the content of the value.

 | Type | Code | Content |
 | --- | --- | --- |
 | `.null` | 0 | nothing |
 | `.integer` | 1 | zig-zag encoded varint |
 | `.double` | 2 | the 8 bytes of the IEEE 754 bit pattern (big endian) |
 | `.string` | 3 | varint byte count, followed by the UTF-8 bytes |
 | `.data` | 4 | varint byte count, followed by the bytes |
 | `.path` | 5 | varint component count, followed by each component as a string |
 | `.list` | 6 | varint element count, followed by the elements as tagged values |
 | `.map` | 7 | varint entry count, followed by the key (as a string) and the tagged value of each entry, sorted by key |

 Varints use 7 bits per byte (least significant group first), with the high bit indicating that more bytes follow.
 A varint has at most 9 bytes: The 9th byte has no continuation bit, and contains the 8 most significant bits.
 This is the same as the varints of Protocol Buffers for values below 2^56.

 - Note: The type codes and the layout are part of the format, and must not be changed.
 */
public struct BinaryValueEncoding: ValueEncoding {

    public init() { }

    public func encode(_ value: Value) throws -> Data {
        var writer = BinaryWriter()
        writer.writeTagged(value)
        return Data(writer.bytes)
    }

    public func decode(_ data: Data) throws -> Value {
        try read(data) { try $0.readTagged() }
    }

    public func encodeContent(of value: Value) throws -> Data {
        var writer = BinaryWriter()
        writer.writeContent(of: value)
        return Data(writer.bytes)
    }

    public func decodeContent(_ data: Data, as type: ValueType) throws -> Value {
        try read(data) { try $0.readContent(as: type) }
    }

    /// Read a value, and ensure that all data is used
    private func read(_ data: Data, using body: (inout BinaryReader) throws -> Value) throws -> Value {
        try data.withUnsafeBytes { bytes in
            var reader = BinaryReader(bytes: bytes)
            let value = try body(&reader)
            guard reader.isAtEnd else {
                throw reader.error("Unexpected bytes after encoded value")
            }
            return value
        }
    }
}

extension ValueType {

    /// The type code used by ``BinaryValueEncoding`` and ``BinaryMessageEncoding``
    var binaryCode: UInt8 {
        switch self {
        case .null: 0
        case .integer: 1
        case .double: 2
        case .string: 3
        case .data: 4
        case .path: 5
        case .list: 6
        case .map: 7
        }
    }

    init?(binaryCode: UInt8) {
        switch binaryCode {
        case 0: self = .null
        case 1: self = .integer
        case 2: self = .double
        case 3: self = .string
        case 4: self = .data
        case 5: self = .path
        case 6: self = .list
        case 7: self = .map
        default: return nil
        }
    }
}

// MARK: - Writing

/// Writes values and primitives in the binary format, shared by ``BinaryValueEncoding`` and ``BinaryMessageEncoding``
struct BinaryWriter {

    var bytes: [UInt8] = []

    mutating func writeTagged(_ value: Value) {
        bytes.append(value.type.binaryCode)
        writeContent(of: value)
    }

    mutating func writeContent(of value: Value) {
        switch value {
        case .null:
            break
        case .integer(let value):
            // Zig-zag encoding keeps small negative numbers short
            let value = Int64(value)
            write(varint: UInt64(bitPattern: (value << 1) ^ (value >> 63)))
        case .double(let value):
            write(value)
        case .string(let value):
            write(value)
        case .data(let value):
            write(count: value.count)
            bytes.append(contentsOf: value)
        case .path(let value):
            write(value)
        case .list(let values):
            write(count: values.count)
            values.forEach { writeTagged($0) }
        case .map(let values):
            write(count: values.count)
            // Sort keys for a deterministic encoding
            for key in values.keys.sorted() {
                write(key)
                writeTagged(values[key]!)
            }
        }
    }

    mutating func write(_ value: Double) {
        withUnsafeBytes(of: value.bitPattern.bigEndian) { bytes.append(contentsOf: $0) }
    }

    mutating func write(_ string: String) {
        let utf8 = string.utf8
        write(count: utf8.count)
        bytes.append(contentsOf: utf8)
    }

    mutating func write(_ path: Path) {
        write(count: path.count)
        path.forEach { write($0) }
    }

    mutating func write(count: Int) {
        write(varint: UInt64(count))
    }

    mutating func write(varint value: UInt64) {
        var value = value
        // The first 8 bytes contain 7 bits each, with the high bit indicating that more bytes follow
        for _ in 0..<8 {
            guard value >= 0x80 else {
                bytes.append(UInt8(value))
                return
            }
            bytes.append(UInt8(truncatingIfNeeded: value) | 0x80)
            value >>= 7
        }
        // The 9th byte contains the remaining 8 bits
        bytes.append(UInt8(value))
    }
}

// MARK: - Reading

/// Reads values and primitives in the binary format, shared by ``BinaryValueEncoding`` and ``BinaryMessageEncoding``
struct BinaryReader {

    /// The maximum nesting depth of lists, maps and trees, to prevent stack overflows on malicious input
    static let maximumDepth = 512

    let bytes: UnsafeRawBufferPointer

    var offset = 0

    /// The current nesting depth
    private var depth = 0

    init(bytes: UnsafeRawBufferPointer) {
        self.bytes = bytes
    }

    var isAtEnd: Bool {
        offset == bytes.count
    }

    func error(_ description: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "\(description) (at offset \(offset))"))
    }

    /// The error for an unknown value type, separate from the recursive functions to keep their stack frames small
    func unknownValueType(_ code: UInt8) -> DecodingError {
        error("Unknown value type \(code)")
    }

    /// Increase the nesting depth, ensuring that the maximum depth is not exceeded
    mutating func enterNested() throws {
        depth += 1
        guard depth <= Self.maximumDepth else {
            throw error("Maximum nesting depth exceeded")
        }
    }

    /// Decrease the nesting depth after a nested element was read
    mutating func leaveNested() {
        depth -= 1
    }

    mutating func readTagged() throws -> Value {
        let code = try readByte()
        guard let type = ValueType(binaryCode: code) else {
            throw unknownValueType(code)
        }
        return try readContent(as: type)
    }

    mutating func readContent(as type: ValueType) throws -> Value {
        switch type {
        case .null:
            return .null
        case .integer:
            let raw = try readVarint()
            return .integer(Int(truncatingIfNeeded: Int64(bitPattern: (raw >> 1) ^ (0 &- (raw & 1)))))
        case .double:
            return .double(try readDouble())
        case .string:
            return .string(try readString())
        case .data:
            return .data(Data(try readBytes(try readCount())))
        case .path:
            return .path(try readPath())
        case .list:
            return .list(try readList())
        case .map:
            return .map(try readMap())
        }
    }

    private mutating func readList() throws -> [Value] {
        try enterNested()
        let count = try readCount()
        var values: [Value] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try readTagged())
        }
        leaveNested()
        return values
    }

    private mutating func readMap() throws -> [String: Value] {
        try enterNested()
        let count = try readCount()
        var values: [String: Value] = [:]
        values.reserveCapacity(count)
        for _ in 0..<count {
            let key = try readString()
            values[key] = try readTagged()
        }
        leaveNested()
        return values
    }

    mutating func readByte() throws -> UInt8 {
        guard offset < bytes.count else {
            throw error("Unexpected end of data")
        }
        defer { offset += 1 }
        return bytes[offset]
    }

    private mutating func readBytes(_ count: Int) throws -> UnsafeRawBufferPointer {
        guard count <= bytes.count - offset else {
            throw error("Unexpected end of data")
        }
        defer { offset += count }
        return UnsafeRawBufferPointer(rebasing: bytes[offset..<offset + count])
    }

    mutating func readDouble() throws -> Double {
        let bits = try readBytes(MemoryLayout<UInt64>.size).loadUnaligned(as: UInt64.self)
        return Double(bitPattern: UInt64(bigEndian: bits))
    }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        // The first 8 bytes contain 7 bits each, with the high bit indicating that more bytes follow
        for shift in stride(from: UInt64(0), to: 56, by: 7) {
            let byte = try readByte()
            result |= UInt64(byte & 0x7F) << shift
            if byte < 0x80 {
                return result
            }
        }
        // The 9th byte contains the remaining 8 bits
        return result | UInt64(try readByte()) << 56
    }

    /// Read the number of elements of a collection
    mutating func readCount() throws -> Int {
        let count = try readVarint()
        // Each element needs at least one byte, which also prevents excessive allocations
        guard count <= UInt64(bytes.count - offset) else {
            throw error("Invalid count \(count)")
        }
        return Int(count)
    }

    mutating func readString() throws -> String {
        String(decoding: try readBytes(try readCount()), as: UTF8.self)
    }

    mutating func readPath() throws -> Path {
        let count = try readCount()
        var components: [PathComponent] = []
        components.reserveCapacity(count)
        for _ in 0..<count {
            components.append(try readString())
        }
        return Path(components)
    }
}
