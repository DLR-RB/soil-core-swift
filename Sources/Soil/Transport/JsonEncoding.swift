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
        // Encode the value and type to the top-level container
        try message.value?.encode(in: &container, valueKey: .value, typeKey: .valueType)

        if !message.samples.isEmpty {
            // The samples are wrapped to use the custom encoding of the samples
            let mapped = message.samples.map(JsonSample.init)
            try container.encode(mapped, forKey: .samples)
        }
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
        var value: Value?
        if container.contains(.value) {
            value = try Value.decode(from: container, valueKey: .value, typeKey: .valueType)
        }
        let samples = try container.decodeIfPresent([JsonSample].self, forKey: .samples)?.map { $0.sample } ?? []
        let count = try container.decodeIfPresent(Int.self, forKey: .count)
        let depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        let time = try container.decodeIfPresent(Double.self, forKey: .time).map { Timestamp(timeIntervalSince1970: $0) }
        let end = try container.decodeIfPresent(Double.self, forKey: .end).map { Timestamp(timeIntervalSince1970: $0) }
        let id = try container.decodeIfPresent(Int.self, forKey: .id)

        self.message = Message(
            type: type,
            path: path,
            value: value,
            time: time,
            samples: samples,
            count: count,
            depth:depth,
            end: end,
            id: id)
    }
}

/**
 Wrapper to use a custom encoding for samples in JSON messages
 */
private struct JsonSample {

    /// The wrapped sample
    let sample: Sample

    enum CodingKeys: String, CodingKey {
        case value
        case type
        case time
    }
}

extension JsonSample: Encodable {

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try sample.value.encode(in: &container, valueKey: .value, typeKey: .type)
        try container.encodeIfPresent(sample.timestamp?.timeIntervalSince1970, forKey: .time)
    }
}

extension JsonSample: Decodable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try Value.decode(from: container, valueKey: .value, typeKey: .type)
        let time = try container.decode(Double.self, forKey: .time)
        self.sample = .init(value: value, timestamp: .init(timeIntervalSince1970: time))
    }
}

private extension Value {

    func encode<T>(in container: inout KeyedEncodingContainer<T>, valueKey: T, typeKey: T) throws {
        let type = self.type
        switch type {
            case .data, .integer: try container.encode(type.rawValue, forKey: typeKey)
            default: break
        }
        switch self {
            case .null: try container.encodeNil(forKey: valueKey)
            case .integer(let value): try container.encode(value, forKey: valueKey)
            case .double(let value): try container.encode(value, forKey: valueKey)
            case .string(let value): try container.encode(value, forKey: valueKey)
            case .data(let value): try container.encode(value, forKey: valueKey)
            case .path(let value): try container.encode(value, forKey: valueKey)
        }
    }

    static func decode<T>(from container: KeyedDecodingContainer<T>, valueKey: T, typeKey: T) throws -> Value {
        if let type = try container.decodeIfPresent(ValueType.self, forKey: typeKey) {
            switch type {
                case .null: return .null
                case .data:
                    let value = try container.decode(Data.self, forKey: valueKey)
                    return .data(value)
                case .integer:
                    let value = try container.decode(Int.self, forKey: valueKey)
                    return .integer(value)
                case .double:
                    let value = try container.decode(Double.self, forKey: valueKey)
                    return .double(value)
                case .string:
                    let value = try container.decode(String.self, forKey: valueKey)
                    return .string(value)
                case .path:
                    let value = try container.decode(Path.self, forKey: valueKey)
                    return .path(value)
            }
        }

        // No type information, so try to detect it
        if try container.decodeNil(forKey: valueKey) {
            return .null
        }
        if let value = try? container.decode(Double.self, forKey: valueKey) {
            return .double(value)
        }
        if let value = try? container.decode(String.self, forKey: valueKey) {
            return .string(value)
        }
        let value = try container.decode(Path.self, forKey: valueKey)
        return .path(value)
    }
}