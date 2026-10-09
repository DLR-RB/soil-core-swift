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

    /**
     A list of values.
     */
    case list([Value])

    /**
     Values associated with string keys
     */
    case map([String: Value])

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

    /// The list, if present
    public var listValue: [Value]? {
        if case let .list(value) = self { return value }
        return nil
    }

    /// The map, if present
    public var mapValue: [String: Value]? {
        if case let .map(value) = self { return value }
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
        case .list: .list
        case .map: .map
        }
    }
}

extension Value: Equatable {

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
        case .list(let value): value.map { $0.description }.joined(separator: ", ")
        case .map(let value): value.map { "\($0.key) = \($0.value)" }.joined(separator: ", ")
        }
    }
}