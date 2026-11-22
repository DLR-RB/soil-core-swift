import Foundation

/**
 The keys used to encode messages in a JSON format.

 Conforming types are usually enums with a `String` raw value for each case.
 */
protocol JsonCodingKeys: CodingKey {
    static var message: Self { get }
    static var path: Self { get }
    static var value: Self { get }
    static var type: Self { get }
    static var samples: Self { get }
    static var count: Self { get }
    static var depth: Self { get }
    static var time: Self { get }
    static var end: Self { get }
    static var id: Self { get }
    static var children: Self { get }
}

/**
 Describes the properties in which the different JSON encodings differ.

 The actual encoding and decoding logic is shared in ``JsonCoding``.
 */
protocol JsonFormat {

    /// The keys used for the fields of the JSON objects
    associatedtype Keys: JsonCodingKeys

    /// The representation of message and value types
    associatedtype Tag: Codable

    static func tag(for type: MessageType) -> Tag

    static func messageType(from tag: Tag) -> MessageType?

    static func tag(for type: ValueType) -> Tag

    static func valueType(from tag: Tag) -> ValueType?
}

/**
 The shared implementation of the JSON message encodings, parameterized by the concrete format.
 */
enum JsonCoding<Format: JsonFormat> {

    typealias Keys = Format.Keys

    /**
     A wrapper to create a custom encoding and decoding for JSON
     */
    struct JsonMessage {

        let message: Message
    }

    struct JsonSampleTree: SampleTree, Sendable, Decodable {

        /// The samples at this tree node
        let samples: [Sample]

        /// The child nodes of the tree, indexed by their path component.
        let _children: [PathComponent : JsonSampleTree]

        var children: [PathComponent : any SampleTree] {
            _children
        }

        init(samples: [Sample] = [], children: [PathComponent : any SampleTree] = [:]) {
            self.samples = samples
            self._children = children.mapValues { JsonSampleTree(samples: $0.samples, children: $0.children) }
        }

        init(from container: KeyedDecodingContainer<Keys>) throws {
            let samples = try container.decodeIfPresent([JsonSample].self, forKey: .samples)?.map { $0.sample } ?? []
            if container.contains(.value) {
                let value = try JsonCoding.decodeValue(from: container)
                let time = try container.decodeIfPresent(Double.self, forKey: .time).map { Timestamp(timeIntervalSince1970: $0) }
                self.samples = (samples + [.init(value: value, timestamp: time)]).sorted()
            } else {
                self.samples = samples.sorted()
            }

            self._children = try container.decodeIfPresent([PathComponent : JsonSampleTree].self, forKey: .children) ?? [:]
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            try self.init(from: container)
        }
    }

    /**
     Wrapper to use a custom encoding for samples in JSON messages
     */
    struct JsonSample {

        /// The wrapped sample
        let sample: Sample
    }

    struct ListElement {

        let values: [Value]
    }

    struct MapElement {

        let values: [String: Value]
    }
}

extension JsonCoding.JsonMessage: Encodable {

    func encode(to encoder: any Encoder) throws {
        // Encode the message in a single top-level container
        var container = encoder.container(keyedBy: Format.Keys.self)
        // Only encode message type if not a data message
        if message.type != .data {
            try container.encode(Format.tag(for: message.type), forKey: .message)
        }
        // If the path is absent, then it defaults to an empty path
        if !message.path.isEmpty {
            try container.encode(message.path, forKey: .path)
        }
        // Encode data to the top-level container

        // There is a possibly invalid message where the `time` is set in addition to data being present
        // We ensure that the timestamp is not written into the message if any samples are provided
        // so that decoding does not fail
        try JsonCoding.encode(message.data, to: &container, canUseRootContainer: message.time == nil)

        try container.encodeIfPresent(message.count, forKey: .count)
        try container.encodeIfPresent(message.depth, forKey: .depth)
        try container.encodeIfPresent(message.time?.timeIntervalSince1970, forKey: .time)
        try container.encodeIfPresent(message.end?.timeIntervalSince1970, forKey: .end)
        try container.encodeIfPresent(message.id, forKey: .id)
    }
}

extension JsonCoding.JsonMessage: Decodable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Format.Keys.self)
        let type: MessageType
        if let rawType = try container.decodeIfPresent(Format.Tag.self, forKey: .message) {
            guard let t = Format.messageType(from: rawType) else {
                throw DecodingError.typeMismatch(MessageType.self, .init(codingPath: [], debugDescription: "Unknown message type: \(rawType)"))
            }
            type = t
        } else {
            type = .data
        }
        let path = try container.decodeIfPresent(Path.self, forKey: .path) ?? []
        let count = try container.decodeIfPresent(Int.self, forKey: .count)
        let depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        let time: Timestamp?
        if !container.contains(.value) {
            time = try container.decodeIfPresent(Double.self, forKey: .time).map { Timestamp(timeIntervalSince1970: $0) }
        } else {
            // If a value is present, then the timestamp is decoded as part of the sample
            time = nil
        }
        let end = try container.decodeIfPresent(Double.self, forKey: .end).map { Timestamp(timeIntervalSince1970: $0) }
        let id = try container.decodeIfPresent(Int.self, forKey: .id)
        let data = try JsonCoding.JsonSampleTree(from: container)

        self.message = Message(
            type: type,
            path: path,
            time: time,
            data: data,
            count: count,
            depth:depth,
            end: end,
            id: id)
    }
}

extension JsonCoding.JsonSample: Encodable {

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Format.Keys.self)
        try JsonCoding.encode(sample.value, in: &container)
        try container.encodeIfPresent(sample.timestamp?.timeIntervalSince1970, forKey: .time)
    }
}

extension JsonCoding.JsonSample: Decodable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Format.Keys.self)
        let value = try JsonCoding.decodeValue(from: container)
        let time = try container.decode(Double.self, forKey: .time)
        self.sample = .init(value: value, timestamp: .init(timeIntervalSince1970: time))
    }
}

extension JsonCoding.ListElement: Codable {

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Value] = []
        while !container.isAtEnd {
            let rawType = try container.decode(Format.Tag.self)
            let value = try JsonCoding.decodeValue(from: &container, rawType: rawType)
            values.append(value)
        }
        self.values = values
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in values {
            try JsonCoding.encode(value, in: &container)
        }
    }
}

extension JsonCoding.MapElement: Codable {

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [String: Value] = [:]
        while !container.isAtEnd {
            let key = try container.decode(String.self)
            let rawType = try container.decode(Format.Tag.self)
            let value = try JsonCoding.decodeValue(from: &container, rawType: rawType)
            values[key] = value
        }
        self.values = values
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for (key, value) in values {
            try container.encode(key)
            try JsonCoding.encode(value, in: &container)
        }
    }
}

private struct StringKey: CodingKey {

    let stringValue: String

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? {
        Int(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
    }
}

// MARK: Sample trees

extension JsonCoding {

    /**
    - Parameter canUseRootContainer: Indicates if a single sample can be encoded directly in the provided container
     */
    static func encode(_ tree: any SampleTree, to container: inout KeyedEncodingContainer<Keys>, canUseRootContainer: Bool = true) throws {
        let samples = tree.samples
        switch samples.count {
            case 0: break
            case 1:
                guard canUseRootContainer else {
                    // Encode the single sample within the `samples` field,
                    // because the `time` field is already used
                    fallthrough
                }
                let sample = samples[0]
                try encode(sample.value, in: &container)
                try container.encodeIfPresent(sample.timestamp?.timeIntervalSince1970, forKey: .time)
            default:
                try container.encode(samples.map(JsonSample.init), forKey: .samples)
        }

        let children = tree.children
        guard !children.isEmpty else {
            return
        }

        var childrenContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .children)
        for (name, child) in children {
            var childContainer = childrenContainer.nestedContainer(keyedBy: Keys.self, forKey: StringKey(stringValue: name))
            try encode(child, to: &childContainer)
        }
    }
}

// MARK: Values

extension JsonCoding {

    /**
     Encode a value to a container.

     The value is encoded either as a number, nil, a string, or a list.
     If the string represents data, the number represents an integer,
     or the list represents a map, then the value type is added to disambiguate.
    */
    static func encode(_ value: Value, in container: inout KeyedEncodingContainer<Keys>) throws {
        let type = value.type
        switch type {
        case .data, .integer, .list, .map: try container.encode(Format.tag(for: type), forKey: .type)
            default: break
        }
        switch value {
            case .null: try container.encodeNil(forKey: .value)
            case .integer(let value): try container.encode(value, forKey: .value)
            case .double(let value): try container.encode(value, forKey: .value)
            case .string(let value): try container.encode(value, forKey: .value)
            case .data(let value): try container.encode(value, forKey: .value)
            case .path(let value): try container.encode(value, forKey: .value)
            case .list(let value): try container.encode(ListElement(values: value), forKey: .value)
            case .map(let value): try container.encode(MapElement(values: value), forKey: .value)
        }
    }

    static func encode(_ value: Value, in container: inout UnkeyedEncodingContainer) throws {
        try container.encode(Format.tag(for: value.type))
        switch value {
            case .null: try container.encodeNil()
            case .integer(let value): try container.encode(value)
            case .double(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .data(let value): try container.encode(value)
            case .path(let value): try container.encode(value)
            case .list(let value): try container.encode(ListElement(values: value))
            case .map(let value): try container.encode(MapElement(values: value))
        }
    }

    static func decodeValue(from container: KeyedDecodingContainer<Keys>) throws -> Value {
        guard let rawType = try container.decodeIfPresent(Format.Tag.self, forKey: .type) else {
            // No type information, so try to detect it
            if try container.decodeNil(forKey: .value) {
                return .null
            }
            if let value = try? container.decode(Double.self, forKey: .value) {
                return .double(value)
            }
            if let value = try? container.decode(String.self, forKey: .value) {
                return .string(value)
            }
            let value = try container.decode(Path.self, forKey: .value)
            return .path(value)
        }

        switch try valueType(from: rawType) {
            case .null: return .null
            case .data:
                let value = try container.decode(Data.self, forKey: .value)
                return .data(value)
            case .integer:
                let value = try container.decode(Int.self, forKey: .value)
                return .integer(value)
            case .double:
                let value = try container.decode(Double.self, forKey: .value)
                return .double(value)
            case .string:
                let value = try container.decode(String.self, forKey: .value)
                return .string(value)
            case .path:
                let value = try container.decode(Path.self, forKey: .value)
                return .path(value)
            case .list:
                let value = try container.decode(ListElement.self, forKey: .value)
                return .list(value.values)
            case .map:
                let value = try container.decode(MapElement.self, forKey: .value)
                return .map(value.values)
        }
    }

    /**
     Decode a value from an unkeyed container.

     Values in unkeyed containers (lists and maps) are always preceded by their type.
     */
    static func decodeValue(from container: inout UnkeyedDecodingContainer, rawType: Format.Tag) throws -> Value {
        switch try valueType(from: rawType) {
            case .null:
                _ = try container.decodeNil()
                return .null
            case .data:
                let value = try container.decode(Data.self)
                return .data(value)
            case .integer:
                let value = try container.decode(Int.self)
                return .integer(value)
            case .double:
                let value = try container.decode(Double.self)
                return .double(value)
            case .string:
                let value = try container.decode(String.self)
                return .string(value)
            case .path:
                let value = try container.decode(Path.self)
                return .path(value)
            case .list:
                let value = try container.decode(ListElement.self)
                return .list(value.values)
            case .map:
                let value = try container.decode(MapElement.self)
                return .map(value.values)
        }
    }

    private static func valueType(from rawType: Format.Tag) throws -> ValueType {
        guard let type = Format.valueType(from: rawType) else {
            throw DecodingError.valueNotFound(ValueType.self, .init(codingPath: [], debugDescription: "Unknown value type: \(rawType)", underlyingError: nil))
        }
        return type
    }
}
