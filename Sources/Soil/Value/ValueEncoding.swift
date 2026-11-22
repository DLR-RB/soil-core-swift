import Foundation

/**
 An encoding that converts values to binary data and back.

 Values can be encoded in two forms:
 - **Tagged** (``encode(_:)`` and ``decode(_:)``): The data contains the value type, so it can be decoded on its own.
 - **Content only** (``encodeContent(of:)`` and ``decodeContent(_:as:)``): The data contains only the content of the value,
   and the type must be provided for decoding. This is useful if the type is stored separately, e.g. in a database column.

 Both forms support all value types. Nested values (elements of lists and maps) are always tagged.

 The library provides ``BinaryValueEncoding``, ``JSONValueEncoding`` and ``CompactJSONValueEncoding``.
 */
public protocol ValueEncoding: Sendable {

    /**
     Encode a value including its type.
     - Parameter value: The value to encode
     - Returns: The encoded data
     */
    func encode(_ value: Value) throws -> Data

    /**
     Decode a value encoded with ``encode(_:)``.
     - Parameter data: The encoded data
     - Returns: The decoded value
     */
    func decode(_ data: Data) throws -> Value

    /**
     Encode only the content of a value, without its type.
     - Parameter value: The value to encode
     - Returns: The encoded content
     */
    func encodeContent(of value: Value) throws -> Data

    /**
     Decode a value encoded with ``encodeContent(of:)``.
     - Parameter data: The encoded content
     - Parameter type: The type of the encoded value
     - Returns: The decoded value, which has the given type
     */
    func decodeContent(_ data: Data, as type: ValueType) throws -> Value
}
