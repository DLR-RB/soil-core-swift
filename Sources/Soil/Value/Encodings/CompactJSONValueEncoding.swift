import Foundation

/**
 Encodes values as compact JSON (UTF-8), in the same representation as values in messages of ``CompactJsonEncoding``.

 The format is the same as for ``JSONValueEncoding``, except that types are identified by integers instead of names,
 e.g. `[1,5]` for an integer.
 The type codes are the same as for ``BinaryValueEncoding``.
 */
public struct CompactJSONValueEncoding: ValueEncoding {

    public init() { }

    public func encode(_ value: Value) throws -> Data {
        try JsonCoding<CompactJsonFormat>.encodeTagged(value)
    }

    public func decode(_ data: Data) throws -> Value {
        try JsonCoding<CompactJsonFormat>.decodeTagged(data)
    }

    public func encodeContent(of value: Value) throws -> Data {
        try JsonCoding<CompactJsonFormat>.encodeContent(of: value)
    }

    public func decodeContent(_ data: Data, as type: ValueType) throws -> Value {
        try JsonCoding<CompactJsonFormat>.decodeContent(data, as: type)
    }
}
