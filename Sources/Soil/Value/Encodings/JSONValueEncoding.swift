import Foundation

/**
 Encodes values as JSON (UTF-8), in the same representation as values in messages of ``JsonEncoding``.

 JSON can be read by most other tools, but is larger and slower than ``BinaryValueEncoding``.
 A tagged value is an array of the type name and the content, e.g. `["integer",5]`.

 | Type | Content |
 | --- | --- |
 | `.null` | `null` |
 | `.integer` | a number |
 | `.double` | a number, or the strings `"nan"`, `"inf"` and `"-inf"` |
 | `.string` | a string |
 | `.data` | a Base64 string |
 | `.path` | an array of strings |
 | `.list` | an array of the types and contents of the elements, e.g. `["integer",1,"string","x"]` |
 | `.map` | an array of the keys, types and contents of the entries, sorted by key, e.g. `["a","integer",1]` |

 Integers outside of the range of `Int` are clamped, and doubles that are too large become infinity.
 */
public struct JSONValueEncoding: ValueEncoding {

    public init() { }

    public func encode(_ value: Value) throws -> Data {
        try JsonCoding<StandardJsonFormat>.encodeTagged(value)
    }

    public func decode(_ data: Data) throws -> Value {
        try JsonCoding<StandardJsonFormat>.decodeTagged(data)
    }

    public func encodeContent(of value: Value) throws -> Data {
        try JsonCoding<StandardJsonFormat>.encodeContent(of: value)
    }

    public func decodeContent(_ data: Data, as type: ValueType) throws -> Value {
        try JsonCoding<StandardJsonFormat>.decodeContent(data, as: type)
    }
}
