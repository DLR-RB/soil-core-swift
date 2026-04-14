import Foundation

/**
 An encoding that represents messages as JSON objects
 */
public final class JsonEncoding: Sendable {

    /// The encoder used to encode messages to binary data
    private let encoder: JSONEncoder

    /// The decoder used to decode messages from binary data
    private let decoder: JSONDecoder

    /**
     Create a JSON encoding layer.
     - Parameter encoder: The encoder used to encode messages
     - Parameter decoder: The decoder used to decode messages
     */
    public init(encoder: JSONEncoder = .init(), decoder: JSONDecoder = .init()) {
        self.encoder = encoder
        self.decoder = decoder
    }
}

extension JsonEncoding: MessageEncoding {

    /**
     Convert a message to JSON data for transmission.
     - Parameter message: The message to encode
     - Returns: The JSON data of the encoded message
     - Throws: An error, if the message could not be encoded
     */
    public func encode(_ message: Message) throws -> Data {
        // Wrap the message in a JSON message to use the custom encoding
        try encoder.encode(JsonMessage(message: message))
    }

    /**
     Extract a message from JSON data.
     - Parameter data: The JSON message data
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    public func decode(_ data: Data) throws -> Message {
        // Decode the wrapper to use the custom format
        try decoder.decode(JsonMessage.self, from: data).message
    }
}

/**
 A wrapper to create a custom encoding and decoding for JSON
 */
private struct JsonMessage {

    let message: Message
}

extension JsonMessage: Encodable {

    enum CodingKeys: String, CodingKey {
        case type
        case path
        case value
        case valueType
        case samples
        case count
        case depth
        case time
        case end
        case id
        case children
    }

    func encode(to encoder: any Encoder) throws {
        // Encode the message in a single top-level container
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode message type if not a data message
        if message.type != .data {
            try container.encode(message.type.rawValue, forKey: .type)
        }
        // If the path is absent, then it defaults to an empty path
        if !message.path.isEmpty {
            try container.encode(message.path, forKey: .path)
        }
        // Encode data to the top-level container

        // There is a possibly invalid message where the `time` is set in addition to data being present
        // We ensure that the timestamp is not written into the message if any samples are provided
        // so that decoding does not fail
        try message.data.encode(to: &container, canUseRootContainer: message.time == nil)

        try container.encodeIfPresent(message.count, forKey: .count)
        try container.encodeIfPresent(message.depth, forKey: .depth)
        try container.encodeIfPresent(message.time?.timeIntervalSince1970, forKey: .time)
        try container.encodeIfPresent(message.end?.timeIntervalSince1970, forKey: .end)
        try container.encodeIfPresent(message.id, forKey: .id)
    }
}

extension JsonMessage: Decodable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(MessageType.self, forKey: .type) ?? .data
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
        let data = try JsonSampleTree(from: container)

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

private struct JsonSampleTree: SampleTree, Sendable, Decodable {

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

    init(from container: KeyedDecodingContainer<JsonMessage.CodingKeys>) throws {
        let samples = try container.decodeIfPresent([JsonSample].self, forKey: .samples)?.map { $0.sample } ?? []
        if container.contains(.value) {
            let value = try Value.decode(from: container)
            let time = try container.decodeIfPresent(Double.self, forKey: .time).map { Timestamp(timeIntervalSince1970: $0) }
            self.samples = (samples + [.init(value: value, timestamp: time)]).sorted()
        } else {
            self.samples = samples.sorted()
        }

        self._children = try container.decodeIfPresent([PathComponent : JsonSampleTree].self, forKey: .children) ?? [:]
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: JsonMessage.CodingKeys.self)
        try self.init(from: container)
    }
}

private extension SampleTree {

    /**
    - Parameter canUseRootContainer: Indicates if a single sample can be encoded directly in the provided container
     */
    func encode(to container: inout KeyedEncodingContainer<JsonMessage.CodingKeys>, canUseRootContainer: Bool = true) throws {
        let samples = samples
        switch samples.count {
            case 0: break
            case 1:
                guard canUseRootContainer else {
                    // Encode the single sample within the `samples` field,
                    // because the `time` field is already used
                    fallthrough
                }
                let sample = samples[0]
                try sample.value.encode(in: &container)
                try container.encodeIfPresent(sample.timestamp?.timeIntervalSince1970, forKey: .time)
            default:
                try container.encode(samples.map(JsonSample.init), forKey: .samples)
        }

        let children = children
        guard !children.isEmpty else {
            return
        }

        var childrenContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .children)
        for (name, child) in children {
            var childContainer = childrenContainer.nestedContainer(keyedBy: JsonMessage.CodingKeys.self, forKey: StringKey(stringValue: name))
            try child.encode(to: &childContainer)
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

/**
 Wrapper to use a custom encoding for samples in JSON messages
 */
private struct JsonSample {

    /// The wrapped sample
    let sample: Sample
}

extension JsonSample: Encodable {

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: JsonMessage.CodingKeys.self)
        try sample.value.encode(in: &container)
        try container.encodeIfPresent(sample.timestamp?.timeIntervalSince1970, forKey: .time)
    }
}

extension JsonSample: Decodable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: JsonMessage.CodingKeys.self)
        let value = try Value.decode(from: container)
        let time = try container.decode(Double.self, forKey: .time)
        self.sample = .init(value: value, timestamp: .init(timeIntervalSince1970: time))
    }
}

private extension Value {

    /**
     Encode a value to a container.

     The value is encoded either as a number, nil, or a string.
     If the string represents data or the number represents an integer,
     then the value type is added to disambiguate.
    */
    func encode(in container: inout KeyedEncodingContainer<JsonMessage.CodingKeys>) throws {
        let type = self.type
        switch type {
            case .data, .integer: try container.encode(type.rawValue, forKey: .valueType)
            default: break
        }
        switch self {
            case .null: try container.encodeNil(forKey: .value)
            case .integer(let value): try container.encode(value, forKey: .value)
            case .double(let value): try container.encode(value, forKey: .value)
            case .string(let value): try container.encode(value, forKey: .value)
            case .data(let value): try container.encode(value, forKey: .value)
            case .path(let value): try container.encode(value, forKey: .value)
        }
    }

    static func decode(from container: KeyedDecodingContainer<JsonMessage.CodingKeys>) throws -> Value {
        if let type = try container.decodeIfPresent(ValueType.self, forKey: .valueType) {
            switch type {
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
            }
        }

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
}