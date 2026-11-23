
/**
 An enum indicating the primitive value types
 */
public enum ValueType: String, Sendable, Codable {

    /// The absence of a value, represented as ``nil``
    case null

    /// Unspecified binary data, represented as ``Data``
    case data

    /// A natural number, represented as ``Int``
    case integer

    /// A decimal value, represented as ``Double``
    case double

    /// A textual value, represented as ``String``
    case string

    /// A path value, represented as ``Path``
    case path

    /// A list of values
    case list

    /// Values associated with string keys
    case map
}

extension ValueType: CustomStringConvertible {

    public var description: String {
        rawValue
    }
}
