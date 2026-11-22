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
        case .list(let value): value.map { $0.description }.joined(separator: ", ")
        case .map(let value): value.map { "\($0.key) = \($0.value)" }.joined(separator: ", ")
        }
    }
}
// MARK: Literals

extension Value: ExpressibleByNilLiteral {

    /// Create a `.null` value from `nil`
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension Value: ExpressibleByIntegerLiteral {

    /// Create an `.integer` value from an integer literal
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension Value: ExpressibleByFloatLiteral {

    /// Create a `.double` value from a floating point literal
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension Value: ExpressibleByBooleanLiteral {

    /// Create an `.integer` value (`0` or `1`) from a boolean literal
    public init(booleanLiteral value: Bool) {
        self = .integer(value ? 1 : 0)
    }
}

extension Value: ExpressibleByStringLiteral {

    /// Create a `.string` value from a string literal
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Value: ExpressibleByArrayLiteral {

    /// Create a `.list` value from an array literal
    public init(arrayLiteral elements: Value...) {
        self = .list(elements)
    }
}

extension Value: ExpressibleByDictionaryLiteral {

    /// Create a `.map` value from a dictionary literal, where later duplicate keys replace earlier ones
    public init(dictionaryLiteral elements: (String, Value)...) {
        self = .map(Dictionary(elements, uniquingKeysWith: { $1 }))
    }
}
