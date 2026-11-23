import Foundation

/**
 A minimal JSON writer that appends UTF-8 bytes to a buffer.

 The writer does not track the structure of the document,
 so callers are responsible for inserting separators and closing containers.
 */
struct JsonWriter {

    /// The UTF-8 bytes written so far
    private(set) var bytes: [UInt8] = []

    init(capacity: Int = 256) {
        bytes.reserveCapacity(capacity)
    }

    /// The written JSON data
    var data: Data {
        Data(bytes)
    }

    // MARK: Structure

    mutating func write(_ byte: UInt8) {
        bytes.append(byte)
    }

    mutating func beginObject() {
        bytes.append(.openBrace)
    }

    mutating func endObject() {
        bytes.append(.closeBrace)
    }

    mutating func beginArray() {
        bytes.append(.openBracket)
    }

    mutating func endArray() {
        bytes.append(.closeBracket)
    }

    mutating func writeComma() {
        bytes.append(.comma)
    }

    /**
     Write an object key followed by a colon.
     - Parameter key: The key to write, which is escaped if needed
     - Parameter first: Indicates if this is the first key of an object; set to `false` afterwards.
     */
    mutating func writeKey(_ key: String, first: inout Bool) {
        if first {
            first = false
        } else {
            bytes.append(.comma)
        }
        write(key)
        bytes.append(.colon)
    }

    // MARK: Values

    mutating func writeNull() {
        bytes.append(contentsOf: [.n, .u, .l, .l])
    }

    mutating func write(_ value: Int) {
        bytes.append(contentsOf: String(value).utf8)
    }

    /**
     Write a floating point number.

     Integral values are written without a fractional part, as done by `JSONEncoder`.
     - Throws: `EncodingError.invalidValue`, if the value is not finite
     */
    mutating func write(_ value: Double) throws {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Unable to encode \(value) in JSON"))
        }
        var description = value.description
        if description.hasSuffix(".0") {
            description.removeLast(2)
        }
        bytes.append(contentsOf: description.utf8)
    }

    /// Write a string, escaping quotes, backslashes and control characters.
    mutating func write(_ value: String) {
        bytes.append(.quote)
        for byte in value.utf8 {
            switch byte {
                case .quote: bytes.append(contentsOf: [.backslash, .quote])
                case .backslash: bytes.append(contentsOf: [.backslash, .backslash])
                case 0x0A: bytes.append(contentsOf: [.backslash, .n])
                case 0x0D: bytes.append(contentsOf: [.backslash, .r])
                case 0x09: bytes.append(contentsOf: [.backslash, .t])
                case 0x00..<0x20:
                    bytes.append(contentsOf: [.backslash, .u, .zero, .zero])
                    bytes.append(Self.hexDigit(byte >> 4))
                    bytes.append(Self.hexDigit(byte & 0x0F))
                default: bytes.append(byte)
            }
        }
        bytes.append(.quote)
    }

    /// Write binary data as a base64 encoded string
    mutating func write(_ value: Data) {
        bytes.append(.quote)
        bytes.append(contentsOf: value.base64EncodedString().utf8)
        bytes.append(.quote)
    }

    private static func hexDigit(_ value: UInt8) -> UInt8 {
        value < 10 ? .zero + value : 0x61 + value - 10
    }
}

extension UInt8 {
    static let quote = UInt8(ascii: "\"")
    static let backslash = UInt8(ascii: "\\")
    static let slash = UInt8(ascii: "/")
    static let openBrace = UInt8(ascii: "{")
    static let closeBrace = UInt8(ascii: "}")
    static let openBracket = UInt8(ascii: "[")
    static let closeBracket = UInt8(ascii: "]")
    static let comma = UInt8(ascii: ",")
    static let colon = UInt8(ascii: ":")
    static let minus = UInt8(ascii: "-")
    static let plus = UInt8(ascii: "+")
    static let dot = UInt8(ascii: ".")
    static let zero = UInt8(ascii: "0")
    static let nine = UInt8(ascii: "9")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let a = UInt8(ascii: "a")
    static let b = UInt8(ascii: "b")
    static let e = UInt8(ascii: "e")
    static let E = UInt8(ascii: "E")
    static let f = UInt8(ascii: "f")
    static let l = UInt8(ascii: "l")
    static let n = UInt8(ascii: "n")
    static let r = UInt8(ascii: "r")
    static let s = UInt8(ascii: "s")
    static let t = UInt8(ascii: "t")
    static let u = UInt8(ascii: "u")
}
