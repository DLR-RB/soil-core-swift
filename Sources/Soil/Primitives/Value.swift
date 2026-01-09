import Foundation

/**
 A primitive value.
 */
public enum Value {

    case integer(Int)

    case double(Double)

    case string(String)

    case data(Data)

    case path(Path)

    public var integerValue: Int? {
        if case let .integer(value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        if case let .double(value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    public var dataValue: Data? {
        if case let .data(value) = self { return value }
        return nil
    }

    public var pathValue: Path? {
        if case let .path(value) = self { return value }
        return nil
    }

    /// The primitive type of the contained value
    public var type: ValueType {
        switch self {
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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
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

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(ValueType.self)
        switch type {
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

    public var description: String {
        switch self {
        case .integer(let value): String(value)
        case .double(let value): value.formatted(.number.precision(.fractionLength(1...16)))
        case .string(let value): "'\(value)'"
        case .data(let value): value.hex + " (Data)"
        case .path(let value): value.map { "'\($0)'" }.joined(separator: ", ")
        }
    }
}