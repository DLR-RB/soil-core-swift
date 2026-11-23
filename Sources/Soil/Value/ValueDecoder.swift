import Foundation

/**
 A decoder that creates `Decodable` types from SOIL values.

 This decoder is the counterpart to ``ValueEncoder``.
 Keyed containers are read from `.map`, unkeyed containers from `.list`, and primitives from their native SOIL value.
 */
public struct ValueDecoder {

    /// Contextual information for custom `Decodable` implementations
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]

    /// Create a decoder
    public init() { }

    /**
     Decode a value.
     - Parameter type: The type to decode
     - Parameter value: The SOIL value to decode
     - Returns: The decoded value
     */
    public func decode<T: Decodable>(_ type: T.Type = T.self, from value: Value) throws -> T {
        try NodeDecoder(value: value, codingPath: [], sendableUserInfo: userInfo).decodeValue(type)
    }
}

// MARK: - Decoder

private struct NodeDecoder: Decoder {

    let value: Value

    let codingPath: [any CodingKey]

    let sendableUserInfo: [CodingUserInfoKey: any Sendable]

    var userInfo: [CodingUserInfoKey: Any] {
        sendableUserInfo
    }

    func child(_ value: Value, key: any CodingKey) -> NodeDecoder {
        NodeDecoder(value: value, codingPath: codingPath + [key], sendableUserInfo: sendableUserInfo)
    }

    func decodeValue<T: Decodable>(_ type: T.Type) throws -> T {
        if let direct = type as? any DirectValueConvertible.Type {
            guard let result = direct.init(soilValue: value) else {
                throw mismatch(type)
            }
            return result as! T
        }
        return try T(from: self)
    }

    func mismatch(_ type: Any.Type) -> DecodingError {
        .typeMismatch(type, .init(codingPath: codingPath, debugDescription: "Expected \(type), found \(value.type)"))
    }

    func primitive<T: ValueConvertible>(_ type: T.Type) throws -> T {
        guard let result = T(soilValue: value) else {
            throw mismatch(type)
        }
        return result
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .map(let map) = value else {
            throw mismatch([String: Value].self)
        }
        return KeyedDecodingContainer(KeyedContainer(decoder: self, map: map))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard case .list(let list) = value else {
            throw mismatch([Value].self)
        }
        return UnkeyedContainer(decoder: self, list: list)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        SingleContainer(decoder: self)
    }
}

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

    let decoder: NodeDecoder

    let map: [String: Value]

    var codingPath: [any CodingKey] { decoder.codingPath }

    var allKeys: [Key] { map.keys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool {
        map[key.stringValue] != nil
    }

    private func child(_ key: Key) throws -> NodeDecoder {
        guard let value = map[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "No value for key '\(key.stringValue)'"))
        }
        return decoder.child(value, key: key)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        (map[key.stringValue] ?? .null) == .null
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try child(key).primitive(type) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try child(key).primitive(type) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try child(key).primitive(type) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try child(key).primitive(type) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try child(key).primitive(type) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try child(key).primitive(type) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try child(key).primitive(type) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try child(key).primitive(type) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try child(key).primitive(type) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try child(key).primitive(type) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try child(key).primitive(type) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try child(key).primitive(type) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try child(key).primitive(type) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try child(key).primitive(type) }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try child(key).decodeValue(type)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try child(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        try child(key).unkeyedContainer()
    }

    func superDecoder() throws -> any Decoder {
        try superDecoder(forKey: Key(stringValue: "super")!)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        decoder.child(map[key.stringValue] ?? .null, key: key)
    }
}

private struct IndexKey: CodingKey {

    let intValue: Int?

    var stringValue: String { "\(intValue!)" }

    init(intValue: Int) { self.intValue = intValue }

    init?(stringValue: String) { nil }
}

private struct UnkeyedContainer: UnkeyedDecodingContainer {

    let decoder: NodeDecoder

    let list: [Value]

    var codingPath: [any CodingKey] { decoder.codingPath }

    var count: Int? { list.count }

    var isAtEnd: Bool { currentIndex >= list.count }

    private(set) var currentIndex = 0

    init(decoder: NodeDecoder, list: [Value]) {
        self.decoder = decoder
        self.list = list
    }

    private mutating func next() throws -> NodeDecoder {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(Value.self, .init(codingPath: codingPath + [IndexKey(intValue: currentIndex)], debugDescription: "Unkeyed container is at end"))
        }
        let child = decoder.child(list[currentIndex], key: IndexKey(intValue: currentIndex))
        currentIndex += 1
        return child
    }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd, list[currentIndex] == .null else {
            return false
        }
        currentIndex += 1
        return true
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try next().primitive(type) }
    mutating func decode(_ type: String.Type) throws -> String { try next().primitive(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try next().primitive(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try next().primitive(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try next().primitive(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try next().primitive(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try next().primitive(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try next().primitive(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try next().primitive(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try next().primitive(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try next().primitive(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try next().primitive(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try next().primitive(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try next().primitive(type) }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try next().decodeValue(type)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        try next().container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try next().unkeyedContainer()
    }

    mutating func superDecoder() throws -> any Decoder {
        try next()
    }
}

private struct SingleContainer: SingleValueDecodingContainer {

    let decoder: NodeDecoder

    var codingPath: [any CodingKey] { decoder.codingPath }

    func decodeNil() -> Bool { decoder.value == .null }

    func decode(_ type: Bool.Type) throws -> Bool { try decoder.primitive(type) }
    func decode(_ type: String.Type) throws -> String { try decoder.primitive(type) }
    func decode(_ type: Double.Type) throws -> Double { try decoder.primitive(type) }
    func decode(_ type: Float.Type) throws -> Float { try decoder.primitive(type) }
    func decode(_ type: Int.Type) throws -> Int { try decoder.primitive(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try decoder.primitive(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try decoder.primitive(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try decoder.primitive(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try decoder.primitive(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try decoder.primitive(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try decoder.primitive(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try decoder.primitive(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try decoder.primitive(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try decoder.primitive(type) }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decoder.decodeValue(type)
    }
}
