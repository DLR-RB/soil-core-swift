import Foundation

/**
 A type that can be converted to and from a SOIL ``Value``.

 Conforming types can be stored in SOIL trees and exchanged with other SOIL components.
 Conformances are provided for common types, which are mapped to native SOIL value types:

 | Swift type | SOIL value |
 | --- | --- |
 | `Int`, `Int8`, ..., `UInt64` | `.integer` (throws if the value doesn't fit into `Int`) |
 | `Bool` | `.integer` (`0` or `1`) |
 | `Double`, `Float` | `.double` (`Float` fails to convert from values that are too large) |
 | `String` | `.string` |
 | `Data` | `.data` |
 | `Date` | `.double` (seconds since 1970, fails to convert from non-finite values) |
 | `UUID`, `URL` | `.string` |
 | `Optional` | `.null` for `nil` |
 | `Array`, `Set` | `.list` |
 | `Dictionary` with `String` keys | `.map` |

 Enums with a raw value and `Codable` types can declare conformance without implementing anything:

 ```swift
 enum Priority: Int, ValueConvertible {
     case low, high
 }

 struct Address: Codable, ValueConvertible {
     var street: String
     var city: String
 }
 ```

 Raw values are stored directly, while `Codable` types are stored as `.map` or `.list` values,
 so that other SOIL components can read the data without knowing the Swift type.

 Converting to a SOIL value throws if the value can't be represented,
 e.g. for unsigned integers larger than `Int.max`.
 Converting from a SOIL value fails if the value doesn't fit into the type, e.g. `Int8` from `.integer(1000)`.
 Values are never clamped or rounded to the nearest representable value during these conversions.
 Only messages received from other systems are clamped while decoding (see ``JsonEncoding``).
 Conforming types that can always be converted may implement ``soilValue`` without `throws`.
 */
public protocol ValueConvertible: Sendable {

    /**
     Create a value from a SOIL value.
     - Parameter soilValue: The SOIL value to convert
     - Returns: `nil`, if the value can't be converted
     */
    init?(soilValue: Value)

    /**
     The value converted to a SOIL value.
     - Throws: An error, if the value can't be represented as a SOIL value
     */
    var soilValue: Value { get throws }
}

// MARK: Default implementations

extension ValueConvertible where Self: RawRepresentable, RawValue: ValueConvertible {

    public init?(soilValue: Value) {
        guard let rawValue = RawValue(soilValue: soilValue) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public var soilValue: Value {
        get throws { try rawValue.soilValue }
    }
}

extension ValueConvertible where Self: Codable {

    public init?(soilValue: Value) {
        guard let value = try? ValueDecoder().decode(Self.self, from: soilValue) else {
            return nil
        }
        self = value
    }

    public var soilValue: Value {
        get throws { try ValueEncoder().encode(self) }
    }
}

extension ValueConvertible where Self: RawRepresentable & Codable, RawValue: ValueConvertible {

    // Prefer the raw value for enums that are also `Codable`

    public init?(soilValue: Value) {
        guard let rawValue = RawValue(soilValue: soilValue) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public var soilValue: Value {
        get throws { try rawValue.soilValue }
    }
}

// MARK: SOIL value

extension Value: ValueConvertible {

    public init?(soilValue: Value) {
        self = soilValue
    }

    public var soilValue: Value {
        self
    }
}

// MARK: Integers

extension FixedWidthInteger {

    fileprivate init?(integerSoilValue soilValue: Value) {
        switch soilValue {
        case .integer(let value):
            guard let converted = Self(exactly: value) else { return nil }
            self = converted
        case .double(let value):
            guard let converted = Self(exactly: value) else { return nil }
            self = converted
        default:
            return nil
        }
    }

    /// The value as an integer, for types that always fit into `Int`
    fileprivate var integerSoilValue: Value {
        .integer(Int(self))
    }

    /// The value as an integer, for types that may not fit into `Int`
    fileprivate var exactIntegerSoilValue: Value {
        get throws {
            guard let converted = Int(exactly: self) else {
                throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Integer \(self) is too large for a SOIL value"))
            }
            return .integer(converted)
        }
    }
}

extension Int: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { .integer(self) }
}

extension Int8: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { integerSoilValue }
}

extension Int16: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { integerSoilValue }
}

extension Int32: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { integerSoilValue }
}

// `Int64` and `UInt32` don't fit into `Int` on 32-bit platforms (e.g. watchOS)

extension Int64: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { get throws { try exactIntegerSoilValue } }
}

extension UInt: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { get throws { try exactIntegerSoilValue } }
}

extension UInt8: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { integerSoilValue }
}

extension UInt16: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { integerSoilValue }
}

extension UInt32: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { get throws { try exactIntegerSoilValue } }
}

extension UInt64: ValueConvertible {
    public init?(soilValue: Value) { self.init(integerSoilValue: soilValue) }
    public var soilValue: Value { get throws { try exactIntegerSoilValue } }
}

extension Bool: ValueConvertible {

    public init?(soilValue: Value) {
        guard case .integer(let value) = soilValue else {
            return nil
        }
        self = value != 0
    }

    public var soilValue: Value {
        .integer(self ? 1 : 0)
    }
}

// MARK: Floating point

extension BinaryFloatingPoint {

    /// Fails, if a finite value is too large for the type
    fileprivate init?(floatingSoilValue soilValue: Value) {
        switch soilValue {
        case .double(let value):
            self.init(value)
            guard isFinite || !value.isFinite else { return nil }
        case .integer(let value):
            self.init(value)
            guard isFinite else { return nil }
        default: return nil
        }
    }

    fileprivate var floatingSoilValue: Value {
        .double(Double(self))
    }
}

extension Double: ValueConvertible {
    public init?(soilValue: Value) { self.init(floatingSoilValue: soilValue) }
    public var soilValue: Value { floatingSoilValue }
}

extension Float: ValueConvertible {
    public init?(soilValue: Value) { self.init(floatingSoilValue: soilValue) }
    public var soilValue: Value { floatingSoilValue }
}

// MARK: Foundation types

extension String: ValueConvertible {

    public init?(soilValue: Value) {
        guard case .string(let value) = soilValue else {
            return nil
        }
        self = value
    }

    public var soilValue: Value {
        .string(self)
    }
}

extension Data: ValueConvertible {

    public init?(soilValue: Value) {
        guard case .data(let value) = soilValue else {
            return nil
        }
        self = value
    }

    public var soilValue: Value {
        .data(self)
    }
}

extension Date: ValueConvertible {

    public init?(soilValue: Value) {
        switch soilValue {
        case .double(let value):
            guard value.isFinite else { return nil }
            self.init(timeIntervalSince1970: value)
        case .integer(let value): self.init(timeIntervalSince1970: Double(value))
        default: return nil
        }
    }

    public var soilValue: Value {
        .double(timeIntervalSince1970)
    }
}

extension UUID: ValueConvertible {

    public init?(soilValue: Value) {
        guard case .string(let value) = soilValue else {
            return nil
        }
        self.init(uuidString: value)
    }

    public var soilValue: Value {
        .string(uuidString)
    }
}

extension URL: ValueConvertible {

    public init?(soilValue: Value) {
        guard case .string(let value) = soilValue else {
            return nil
        }
        self.init(string: value)
    }

    public var soilValue: Value {
        .string(absoluteString)
    }
}

// MARK: Containers

extension Optional: ValueConvertible where Wrapped: ValueConvertible {

    /**
     Create an optional from a SOIL value.

     If the wrapped type can itself represent `.null` (like ``Value`` or another `Optional`),
     then `.null` is passed to the wrapped type, so that nested values are preserved:
     `Value?` decodes `.null` as `.some(.null)`, and `Int??` as `.some(nil)`.
     */
    public init?(soilValue: Soil.Value) {
        if let value = Wrapped(soilValue: soilValue) {
            self = .some(value)
            return
        }
        guard soilValue == .null else {
            return nil
        }
        self = .none
    }

    public var soilValue: Soil.Value {
        get throws { try self?.soilValue ?? .null }
    }
}

extension Array: ValueConvertible where Element: ValueConvertible {

    public init?(soilValue: Value) {
        switch soilValue {
        case .list(let values):
            var result: [Element] = []
            result.reserveCapacity(values.count)
            for value in values {
                guard let element = Element(soilValue: value) else {
                    return nil
                }
                result.append(element)
            }
            self = result
        default:
            return nil
        }
    }

    public var soilValue: Value {
        get throws { .list(try map { try $0.soilValue }) }
    }
}

extension Set: ValueConvertible where Element: ValueConvertible {

    public init?(soilValue: Value) {
        guard let elements = [Element](soilValue: soilValue) else {
            return nil
        }
        self.init(elements)
    }

    public var soilValue: Value {
        get throws { .list(try map { try $0.soilValue }) }
    }
}

extension Dictionary: ValueConvertible where Key == String, Value: ValueConvertible {

    public init?(soilValue: Soil.Value) {
        guard case .map(let values) = soilValue else {
            return nil
        }
        var result: [String: Value] = [:]
        for (key, value) in values {
            guard let element = Value(soilValue: value) else {
                return nil
            }
            result[key] = element
        }
        self = result
    }

    public var soilValue: Soil.Value {
        get throws { .map(try mapValues { try $0.soilValue }) }
    }
}
