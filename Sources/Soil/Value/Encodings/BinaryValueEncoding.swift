import Foundation

/**
 Encodes values in a compact binary format.

 The encoding doesn't use `Codable`, which makes it faster and smaller than general purpose encoders.

 A tagged value consists of the type code (one byte), followed by the content of the value.

 | Type | Code | Content |
 | --- | --- | --- |
 | `.null` | 0 | nothing |
 | `.integer` | 1 | zig-zag encoded varint |
 | `.double` | 2 | the 8 bytes of the IEEE 754 bit pattern (little endian) |
 | `.string` | 3 | varint byte count, followed by the UTF-8 bytes |
 | `.data` | 4 | varint byte count, followed by the bytes |
 | `.path` | 5 | varint component count, followed by each component as a string |
 | `.list` | 6 | varint element count, followed by the elements as tagged values |
 | `.map` | 7 | varint entry count, followed by the key (as a string) and the tagged value of each entry, sorted by key |

 Varints use 7 bits per byte (least significant group first), with the high bit indicating that more bytes follow.

 - Note: The type codes and the layout are part of the format, and must not be changed.
 */
public struct BinaryValueEncoding: ValueEncoding {

    public init() { }

    public func encode(_ value: Value) throws -> Data {
        var writer = BinaryValueWriter()
        writer.writeTagged(value)
        return Data(writer.bytes)
    }

    public func decode(_ data: Data) throws -> Value {
        try read(data) { try $0.readTagged() }
    }

    public func encodeContent(of value: Value) throws -> Data {
        var writer = BinaryValueWriter()
        writer.writeContent(of: value)
        return Data(writer.bytes)
    }

    public func decodeContent(_ data: Data, as type: ValueType) throws -> Value {
        try read(data) { try $0.readContent(as: type) }
    }

    /// Read a value, and ensure that all data is used
    private func read(_ data: Data, using body: (inout BinaryValueReader) throws -> Value) throws -> Value {
        try data.withUnsafeBytes { bytes in
            var reader = BinaryValueReader(bytes: bytes)
            let value = try body(&reader)
            guard reader.isAtEnd else {
                throw reader.error("Unexpected bytes after encoded value")
            }
            return value
        }
    }
}

extension ValueType {

    /// The type code used by ``BinaryValueEncoding``
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

private struct BinaryValueWriter {

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
            withUnsafeBytes(of: value.bitPattern.littleEndian) { bytes.append(contentsOf: $0) }
        case .string(let value):
            write(value)
        case .data(let value):
            write(count: value.count)
            bytes.append(contentsOf: value)
        case .path(let value):
            write(count: value.count)
            value.forEach { write($0) }
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

    private mutating func write(_ string: String) {
        let utf8 = string.utf8
        write(count: utf8.count)
        bytes.append(contentsOf: utf8)
    }

    private mutating func write(count: Int) {
        write(varint: UInt64(count))
    }

    private mutating func write(varint value: UInt64) {
        var value = value
        while value >= 0x80 {
            bytes.append(UInt8(truncatingIfNeeded: value) | 0x80)
            value >>= 7
        }
        bytes.append(UInt8(value))
    }
}

// MARK: - Reading

private struct BinaryValueReader {

    let bytes: UnsafeRawBufferPointer

    var offset = 0

    init(bytes: UnsafeRawBufferPointer) {
        self.bytes = bytes
    }

    var isAtEnd: Bool {
        offset == bytes.count
    }

    func error(_ description: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "\(description) (at offset \(offset))"))
    }

    mutating func readTagged() throws -> Value {
        let code = try readByte()
        guard let type = ValueType(binaryCode: code) else {
            throw error("Unknown value type \(code)")
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
            let bits = try readBytes(MemoryLayout<UInt64>.size).loadUnaligned(as: UInt64.self)
            return .double(Double(bitPattern: UInt64(littleEndian: bits)))
        case .string:
            return .string(try readString())
        case .data:
            return .data(Data(try readBytes(try readCount())))
        case .path:
            let count = try readCount()
            var components: [PathComponent] = []
            components.reserveCapacity(count)
            for _ in 0..<count {
                components.append(try readString())
            }
            return .path(Path(components))
        case .list:
            let count = try readCount()
            var values: [Value] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try readTagged())
            }
            return .list(values)
        case .map:
            let count = try readCount()
            var values: [String: Value] = [:]
            values.reserveCapacity(count)
            for _ in 0..<count {
                let key = try readString()
                values[key] = try readTagged()
            }
            return .map(values)
        }
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < bytes.count else {
            throw error("Unexpected end of encoded value")
        }
        defer { offset += 1 }
        return bytes[offset]
    }

    private mutating func readBytes(_ count: Int) throws -> UnsafeRawBufferPointer {
        guard count <= bytes.count - offset else {
            throw error("Unexpected end of encoded value")
        }
        defer { offset += count }
        return UnsafeRawBufferPointer(rebasing: bytes[offset..<offset + count])
    }

    private mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            let byte = try readByte()
            guard shift < 64 else {
                throw error("Invalid varint")
            }
            result |= UInt64(byte & 0x7F) << shift
            if byte < 0x80 {
                return result
            }
            shift += 7
        }
    }

    private mutating func readCount() throws -> Int {
        let count = try readVarint()
        // Each element needs at least one byte, which also prevents excessive allocations
        guard count <= UInt64(bytes.count - offset) else {
            throw error("Invalid count \(count)")
        }
        return Int(count)
    }

    private mutating func readString() throws -> String {
        String(decoding: try readBytes(try readCount()), as: UTF8.self)
    }
}
