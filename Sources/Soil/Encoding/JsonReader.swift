import Foundation

/**
 A minimal pull-based JSON reader operating directly on UTF-8 bytes.

 The reader does not build an intermediate representation,
 the caller requests the expected values in order.
 Values can be skipped and later read by resetting the ``offset``.
 */
struct JsonReader {

    /// The maximum nesting depth of arrays and objects, to prevent stack overflows on malicious input
    static let maximumDepth = 512

    /// The kind of the next value, determined by its first byte
    enum Kind {
        case null
        case bool
        case number
        case string
        case array
        case object
    }

    /// The UTF-8 bytes of the document
    private let bytes: UnsafeRawBufferPointer

    /// The offset of the next byte to read
    var offset: Int = 0

    /// The current nesting depth of arrays and objects
    private var depth = 0

    /**
     Create a reader.
     - Parameter bytes: The JSON data. Must remain valid while the reader is in use.
     */
    init(bytes: UnsafeRawBufferPointer) {
        self.bytes = bytes
    }

    // MARK: Errors

    func error(_ description: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "\(description) (at offset \(offset))"))
    }

    // MARK: Whitespace and single bytes

    private mutating func skipWhitespace() {
        while offset < bytes.count {
            switch bytes[offset] {
                case .space, .tab, .newline, .carriageReturn: offset += 1
                default: return
            }
        }
    }

    /// Get the next non-whitespace byte without consuming it
    private mutating func peek() throws -> UInt8 {
        skipWhitespace()
        guard offset < bytes.count else {
            throw error("Unexpected end of data")
        }
        return bytes[offset]
    }

    private mutating func expect(_ byte: UInt8) throws {
        guard try peek() == byte else {
            throw error("Expected '\(Character(Unicode.Scalar(byte)))'")
        }
        offset += 1
    }

    /// Ensure that only whitespace follows the current position
    mutating func expectEnd() throws {
        skipWhitespace()
        guard offset == bytes.count else {
            throw error("Unexpected data after end of document")
        }
    }

    /// Determine the kind of the next value
    mutating func peekKind() throws -> Kind {
        switch try peek() {
            case .n: return .null
            case .t, .f: return .bool
            case .quote: return .string
            case .openBracket: return .array
            case .openBrace: return .object
            case .minus, .zero ... .nine: return .number
            default: throw error("Invalid value")
        }
    }

    // MARK: Containers

    private mutating func enterContainer() throws {
        depth += 1
        guard depth <= Self.maximumDepth else {
            throw error("Maximum nesting depth exceeded")
        }
    }

    /// Consume the opening brace of an object
    mutating func beginObject() throws {
        try expect(.openBrace)
        try enterContainer()
    }

    /**
     Read the next key of an object, or the end of the object.
     - Parameter first: Indicates that no key was read so far; set to `false` afterwards.
     - Returns: The key, or `nil` if the end of the object was reached
     */
    mutating func nextKey(first: inout Bool) throws -> String? {
        if try peek() == .closeBrace {
            offset += 1
            depth -= 1
            return nil
        }
        if first {
            first = false
        } else {
            try expect(.comma)
        }
        guard try peek() == .quote else {
            throw error("Expected object key")
        }
        let key = try readString()
        try expect(.colon)
        return key
    }

    /// Consume the opening bracket of an array
    mutating func beginArray() throws {
        try expect(.openBracket)
        try enterContainer()
    }

    /**
     Advance to the next element of an array.
     - Parameter first: Indicates that no element was read so far; set to `false` afterwards.
     - Returns: `true`, if another element follows, `false` if the end of the array was reached
     */
    mutating func nextElement(first: inout Bool) throws -> Bool {
        if try peek() == .closeBracket {
            offset += 1
            depth -= 1
            return false
        }
        if first {
            first = false
        } else {
            try expect(.comma)
        }
        return true
    }

    // MARK: Literals

    mutating func readNull() throws {
        try readLiteral([.n, .u, .l, .l])
    }

    mutating func readBool() throws -> Bool {
        if try peek() == .t {
            try readLiteral([.t, .r, .u, .e])
            return true
        }
        try readLiteral([.f, .a, .l, .s, .e])
        return false
    }

    private mutating func readLiteral(_ literal: [UInt8]) throws {
        skipWhitespace()
        guard offset + literal.count <= bytes.count else {
            throw error("Unexpected end of data")
        }
        for (index, byte) in literal.enumerated() where bytes[offset + index] != byte {
            throw error("Invalid literal")
        }
        offset += literal.count
    }

    // MARK: Numbers

    /**
     Get the bytes of the next number.
     - Returns: The range of the number, and whether it contains a fraction or exponent
     */
    private mutating func scanNumber() throws -> (range: Range<Int>, isInteger: Bool) {
        skipWhitespace()
        let start = offset
        var isInteger = true
        if offset < bytes.count, bytes[offset] == .minus {
            offset += 1
        }
        let digitsStart = offset
        loop: while offset < bytes.count {
            switch bytes[offset] {
                case .zero ... .nine: break
                case .dot, .e, .E, .plus, .minus: isInteger = false
                default: break loop
            }
            offset += 1
        }
        guard offset > digitsStart, bytes[digitsStart] != .dot else {
            throw error("Invalid number")
        }
        return (start..<offset, isInteger)
    }

    /**
     Read a floating point number.
     - Parameter allowingOverflow: Convert numbers outside of the range of `Double` to infinity, instead of throwing an error
     */
    mutating func readDouble(allowingOverflow: Bool = false) throws -> Double {
        let (range, _) = try scanNumber()
        let string = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range]), as: UTF8.self)
        guard let value = Double(string) else {
            throw error("Invalid number '\(string)'")
        }
        guard value.isFinite || allowingOverflow else {
            throw error("Number out of range '\(string)'")
        }
        return value
    }

    /**
     Read an integer.

     Numbers with a fraction or exponent are accepted, if they represent an integer.
     - Parameter clamping: Clamp numbers outside of the range of `Int` to `Int.min` or `Int.max`, instead of throwing an error
     */
    mutating func readInt(clamping: Bool = false) throws -> Int {
        let start = offset
        let (range, isInteger) = try scanNumber()
        guard isInteger else {
            offset = start
            let double = try readDouble(allowingOverflow: clamping)
            if let value = Int(exactly: double) {
                return value
            }
            // Infinity counts as integral, since it results from a number too large for a double
            guard clamping, double.rounded(.towardZero) == double else {
                throw error("Number is not an integer")
            }
            return double < 0 ? .min : .max
        }
        var index = range.lowerBound
        let isNegative = bytes[index] == .minus
        if isNegative {
            index += 1
        }
        var value = 0
        while index < range.upperBound {
            let digit = Int(bytes[index] &- .zero)
            let (multiplied, overflow1) = value.multipliedReportingOverflow(by: 10)
            let (added, overflow2) = isNegative
                ? multiplied.subtractingReportingOverflow(digit)
                : multiplied.addingReportingOverflow(digit)
            guard !overflow1, !overflow2 else {
                guard clamping else {
                    throw error("Integer out of range")
                }
                return isNegative ? .min : .max
            }
            value = added
            index += 1
        }
        return value
    }

    // MARK: Strings

    mutating func readString() throws -> String {
        try expect(.quote)
        let start = offset
        // Fast path: Strings without escape sequences are decoded directly from the buffer
        while offset < bytes.count {
            switch bytes[offset] {
                case .quote:
                    let string = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[start..<offset]), as: UTF8.self)
                    offset += 1
                    return string
                case .backslash:
                    return try readEscapedString(start: start)
                case 0x00..<0x20:
                    throw error("Unescaped control character in string")
                default:
                    offset += 1
            }
        }
        throw error("Unterminated string")
    }

    private mutating func readEscapedString(start: Int) throws -> String {
        var result = Array(bytes[start..<offset])
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            switch byte {
                case .quote:
                    return String(decoding: result, as: UTF8.self)
                case .backslash:
                    guard offset < bytes.count else {
                        throw error("Unterminated string")
                    }
                    let escaped = bytes[offset]
                    offset += 1
                    switch escaped {
                        case .quote, .backslash, .slash: result.append(escaped)
                        case .b: result.append(0x08)
                        case .f: result.append(0x0C)
                        case .n: result.append(.newline)
                        case .r: result.append(.carriageReturn)
                        case .t: result.append(.tab)
                        case .u: try appendUnicodeEscape(to: &result)
                        default: throw error("Invalid escape sequence")
                    }
                case 0x00..<0x20:
                    throw error("Unescaped control character in string")
                default:
                    result.append(byte)
            }
        }
        throw error("Unterminated string")
    }

    /// Decode a `\uXXXX` escape (with the `\u` already consumed), including surrogate pairs
    private mutating func appendUnicodeEscape(to result: inout [UInt8]) throws {
        let first = try readHex4()
        let scalarValue: UInt32
        if (0xD800..<0xDC00).contains(first) {
            // High surrogate, must be followed by a low surrogate
            guard offset + 2 <= bytes.count, bytes[offset] == .backslash, bytes[offset + 1] == .u else {
                throw error("Unpaired surrogate in string")
            }
            offset += 2
            let second = try readHex4()
            guard (0xDC00..<0xE000).contains(second) else {
                throw error("Invalid surrogate pair in string")
            }
            scalarValue = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
        } else {
            scalarValue = first
        }
        guard let scalar = Unicode.Scalar(scalarValue) else {
            throw error("Invalid unicode escape in string")
        }
        UTF8.encode(scalar) { result.append($0) }
    }

    private mutating func readHex4() throws -> UInt32 {
        guard offset + 4 <= bytes.count else {
            throw error("Unterminated string")
        }
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = bytes[offset]
            let digit: UInt8
            switch byte {
                case .zero ... .nine: digit = byte - .zero
                case 0x41...0x46: digit = byte - 0x41 + 10 // A-F
                case 0x61...0x66: digit = byte - 0x61 + 10 // a-f
                default: throw error("Invalid unicode escape in string")
            }
            value = value << 4 | UInt32(digit)
            offset += 1
        }
        return value
    }

    /// Read a base64 encoded string as binary data
    mutating func readData() throws -> Data {
        let string = try readString()
        guard let data = Data(base64Encoded: string) else {
            throw error("Invalid base64 data")
        }
        return data
    }

    // MARK: Skipping

    /// Skip the next value, including nested containers
    mutating func skipValue() throws {
        switch try peekKind() {
            case .null:
                try readNull()
            case .bool:
                _ = try readBool()
            case .number:
                _ = try scanNumber()
            case .string:
                _ = try readString()
            case .array:
                try beginArray()
                var first = true
                while try nextElement(first: &first) {
                    try skipValue()
                }
            case .object:
                try beginObject()
                var first = true
                while try nextKey(first: &first) != nil {
                    try skipValue()
                }
        }
    }
}
