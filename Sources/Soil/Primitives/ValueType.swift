
/**
 An enum indicating the primitive value types
 */
public enum ValueType: Int {

    /// The absence of a value, represented as ``nil``
    case null = 0

    /// Unspecified binary data, represented as ``Data``
    case data = 1

    /// A natural number, represented as ``Int``
    case integer = 2

    /// A decimal value, represented as ``Double``
    case double = 3

    /// A textual value, represented as ``String``
    case string = 4

    /// A path value, represented as `[String]`
    case path = 5
}

extension ValueType: Codable {

}
