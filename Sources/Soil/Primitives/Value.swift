import Foundation

/**
 A primitive value.
 */
public enum Value: Sendable {

    /**
     The absence of a value.

     In Swift, this is represented as `nil`
     */
    case null

    /**
     A natural number.

     In Swift, this is represented as ``Int``
     */
    case integer(Int)

    /**
     A decimal number.

     In Swift, this is represented as ``Double``
     */
    case double(Double)

    /**
     A textual value.

     In Swift, this is represented as ``String``
     */
    case string(String)

    /**
     A binary data blob

     In Swift, this is represented as ``Data``
     */
    case data(Data)

    /**
     A path.

     In Swift, this is represented as `[String]`
     */
    case path(Path)

    /// The integer value, if present
    public var integerValue: Int? {
        if case let .integer(value) = self { return value }
        return nil
    }

    /// The decimal value, if present
    public var doubleValue: Double? {
        if case let .double(value) = self { return value }
        return nil
    }

    /// The textual value, if present
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// The binary data, if present
    public var dataValue: Data? {
        if case let .data(value) = self { return value }
        return nil
    }

    /// The path, if present
    public var pathValue: Path? {
        if case let .path(value) = self { return value }
        return nil
    }

    /// The primitive type of the contained value
    public var type: ValueType {
        switch self {
        case .null: .null
        case .data: .data
        case .integer: .integer
        case .double: .double
        case .string: .string
        case .path: .path
        }
    }
}

extension Value: Equatable {

}

extension Value: Encodable {

    /**
     Encode a value to an encoder.

     The value is stored in an unkeyed container, where the ``ValueType`` is encoded first,
     followed by the associated value of the case.
     */
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .null:
            break
        case .data(let value):
            try container.encode(ValueType.data)
            try container.encode(value)
        case .integer(let value):
            try container.encode(ValueType.integer)
            try container.encode(value)
        case .double(let value):
            try container.encode(ValueType.double)
            try container.encode(value)
        case .string(let value):
            try container.encode(ValueType.string)
            try container.encode(value)
        case .path(let value):
            try container.encode(ValueType.path)
            try container.encode(value)
        }
    }
}

extension Value: Decodable {

    /**
     Decode a value from an encoder.

     The value is assumed to be stored in an unkeyed container, where the ``ValueType`` is encoded first,
     followed by the associated value of the case.
     */
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(ValueType.self)
        switch type {
        case .null:
            self = .null
        case .integer:
            let value = try container.decode(Int.self)
            self = .integer(value)
        case .double:
            let value = try container.decode(Double.self)
            self = .double(value)
        case .string:
            let value = try container.decode(String.self)
            self = .string(value)
        case .data:
            let value = try container.decode(Data.self)
            self = .data(value)
        case .path:
            let value = try container.decode(Path.self)
            self = .path(value)
        }
    }
}

extension Value: CustomStringConvertible {

    /// A short description of the value
    public var description: String {
        switch self {
        case .null: "null"
        case .integer(let value): String(value)
        case .double(let value): value.formatted(.number.precision(.fractionLength(1...16)))
        case .string(let value): "'\(value)'"
        case .data(let value): value.hex + " (Data)"
        case .path(let value): value.map { "'\($0)'" }.joined(separator: ", ")
        }
    }
}