import Foundation

/**
 An encoder that converts `Encodable` types into SOIL values.

 Keyed containers are encoded as `.map`, unkeyed containers as `.list`, and primitives as their native SOIL value.
 Types with a direct SOIL representation (like `Date`, `Data`, `UUID` and `URL`) use their ``ValueConvertible`` representation.
 */
public struct ValueEncoder {

    /// Contextual information for custom `Encodable` implementations
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]

    /// Create an encoder
    public init() { }

    /**
     Encode a value.
     - Parameter value: The value to encode
     - Returns: The SOIL representation of the value
     */
    public func encode<T: Encodable>(_ value: T) throws -> Value {
        let node = EncodingNode()
        try node.encode(value, codingPath: [], userInfo: userInfo)
        return node.resolved
    }
}

/// Types that are encoded using their ``ValueConvertible`` representation instead of their `Codable` implementation
protocol DirectValueConvertible: ValueConvertible { }

extension Date: DirectValueConvertible { }
extension Data: DirectValueConvertible { }
extension UUID: DirectValueConvertible { }
extension URL: DirectValueConvertible { }

// MARK: - Encoding tree

/// A reference node which collects the encoded data, since containers may be filled after they are created
private final class EncodingNode {

    var value: Value = .null
    var map: [String: EncodingNode]?
    var list: [EncodingNode]?

    var resolved: Value {
        if let map {
            return .map(map.mapValues { $0.resolved })
        }
        if let list {
            return .list(list.map { $0.resolved })
        }
        return value
    }

    func encode<T: Encodable>(_ value: T, codingPath: [any CodingKey], userInfo: [CodingUserInfoKey: any Sendable]) throws {
        if let direct = value as? any DirectValueConvertible {
            self.value = try direct.soilValue
            return
        }
        try value.encode(to: NodeEncoder(node: self, codingPath: codingPath, userInfo: userInfo))
    }
}

private struct NodeEncoder: Encoder {

    let node: EncodingNode

    let codingPath: [any CodingKey]

    let sendableUserInfo: [CodingUserInfoKey: any Sendable]

    init(node: EncodingNode, codingPath: [any CodingKey], userInfo: [CodingUserInfoKey: any Sendable]) {
        self.node = node
        self.codingPath = codingPath
        self.sendableUserInfo = userInfo
    }

    var userInfo: [CodingUserInfoKey: Any] {
        sendableUserInfo
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if node.map == nil {
            node.map = [:]
        }
        return KeyedEncodingContainer(KeyedContainer(encoder: self))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        if node.list == nil {
            node.list = []
        }
        return UnkeyedContainer(encoder: self)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        SingleContainer(encoder: self)
    }

    func child(_ key: any CodingKey) -> (EncodingNode, [any CodingKey]) {
        (EncodingNode(), codingPath + [key])
    }
}

/// Convert a primitive into a SOIL value, or throw if the integer can't be represented
private func integer<T: BinaryInteger>(_ value: T, codingPath: [any CodingKey]) throws -> Value {
    guard let converted = Int(exactly: value) else {
        throw EncodingError.invalidValue(value, .init(codingPath: codingPath, debugDescription: "Integer \(value) is too large for a SOIL value"))
    }
    return .integer(converted)
}

private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

    let encoder: NodeEncoder

    var codingPath: [any CodingKey] { encoder.codingPath }

    private func set(_ value: Value, for key: Key) {
        let node = EncodingNode()
        node.value = value
        encoder.node.map![key.stringValue] = node
    }

    mutating func encodeNil(forKey key: Key) throws { set(.null, for: key) }
    mutating func encode(_ value: Bool, forKey key: Key) throws { set(value.soilValue, for: key) }
    mutating func encode(_ value: String, forKey key: Key) throws { set(.string(value), for: key) }
    mutating func encode(_ value: Double, forKey key: Key) throws { set(.double(value), for: key) }
    mutating func encode(_ value: Float, forKey key: Key) throws { set(.double(Double(value)), for: key) }
    mutating func encode(_ value: Int, forKey key: Key) throws { set(.integer(value), for: key) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { set(try integer(value, codingPath: codingPath + [key]), for: key) }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let (node, path) = encoder.child(key)
        encoder.node.map![key.stringValue] = node
        try node.encode(value, codingPath: path, userInfo: encoder.sendableUserInfo)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let (node, path) = encoder.child(key)
        encoder.node.map![key.stringValue] = node
        return NodeEncoder(node: node, codingPath: path, userInfo: encoder.sendableUserInfo).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        let (node, path) = encoder.child(key)
        encoder.node.map![key.stringValue] = node
        return NodeEncoder(node: node, codingPath: path, userInfo: encoder.sendableUserInfo).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        superEncoder(forKey: Key(stringValue: "super")!)
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        let (node, path) = encoder.child(key)
        encoder.node.map![key.stringValue] = node
        return NodeEncoder(node: node, codingPath: path, userInfo: encoder.sendableUserInfo)
    }
}

private struct IndexKey: CodingKey {

    let intValue: Int?

    var stringValue: String { "\(intValue!)" }

    init(intValue: Int) { self.intValue = intValue }

    init?(stringValue: String) { nil }
}

private struct UnkeyedContainer: UnkeyedEncodingContainer {

    let encoder: NodeEncoder

    var codingPath: [any CodingKey] { encoder.codingPath }

    var count: Int { encoder.node.list!.count }

    private func nextNode() -> (EncodingNode, [any CodingKey]) {
        let (node, path) = encoder.child(IndexKey(intValue: count))
        encoder.node.list!.append(node)
        return (node, path)
    }

    private func append(_ value: Value) {
        nextNode().0.value = value
    }

    private var nextPath: [any CodingKey] { codingPath + [IndexKey(intValue: count)] }

    mutating func encodeNil() throws { append(.null) }
    mutating func encode(_ value: Bool) throws { append(value.soilValue) }
    mutating func encode(_ value: String) throws { append(.string(value)) }
    mutating func encode(_ value: Double) throws { append(.double(value)) }
    mutating func encode(_ value: Float) throws { append(.double(Double(value))) }
    mutating func encode(_ value: Int) throws { append(.integer(value)) }
    mutating func encode(_ value: Int8) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: Int16) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: Int32) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: Int64) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: UInt) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: UInt8) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: UInt16) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: UInt32) throws { append(try integer(value, codingPath: nextPath)) }
    mutating func encode(_ value: UInt64) throws { append(try integer(value, codingPath: nextPath)) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let (node, path) = nextNode()
        try node.encode(value, codingPath: path, userInfo: encoder.sendableUserInfo)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let (node, path) = nextNode()
        return NodeEncoder(node: node, codingPath: path, userInfo: encoder.sendableUserInfo).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        let (node, path) = nextNode()
        return NodeEncoder(node: node, codingPath: path, userInfo: encoder.sendableUserInfo).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        let (node, path) = nextNode()
        return NodeEncoder(node: node, codingPath: path, userInfo: encoder.sendableUserInfo)
    }
}

private struct SingleContainer: SingleValueEncodingContainer {

    let encoder: NodeEncoder

    var codingPath: [any CodingKey] { encoder.codingPath }

    private func set(_ value: Value) {
        encoder.node.value = value
    }

    mutating func encodeNil() throws { set(.null) }
    mutating func encode(_ value: Bool) throws { set(value.soilValue) }
    mutating func encode(_ value: String) throws { set(.string(value)) }
    mutating func encode(_ value: Double) throws { set(.double(value)) }
    mutating func encode(_ value: Float) throws { set(.double(Double(value))) }
    mutating func encode(_ value: Int) throws { set(.integer(value)) }
    mutating func encode(_ value: Int8) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: Int16) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: Int32) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: Int64) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: UInt) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: UInt8) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: UInt16) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: UInt32) throws { set(try integer(value, codingPath: codingPath)) }
    mutating func encode(_ value: UInt64) throws { set(try integer(value, codingPath: codingPath)) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        try encoder.node.encode(value, codingPath: codingPath, userInfo: encoder.sendableUserInfo)
    }
}
