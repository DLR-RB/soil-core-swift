
/**
 An enum indicating the primitive value types
 */
public enum ValueType: Int {

    /// Unspecified binary data
    case data = 0

    /// A natural number
    case integer = 1

    /// A decimal value
    case double = 2

    /// A textual value
    case string = 3

    /// A path value (an array of strings)
    case path = 4
}

extension ValueType: Codable {

}
