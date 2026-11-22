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
        try encoder.encode(JsonCoding<StandardJsonFormat>.JsonMessage(message: message))
    }

    /**
     Extract a message from JSON data.
     - Parameter data: The JSON message data
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    public func decode(_ data: Data) throws -> Message {
        // Decode the wrapper to use the custom format
        try decoder.decode(JsonCoding<StandardJsonFormat>.JsonMessage.self, from: data).message
    }
}

/**
 The verbose JSON format, using descriptive keys and type names.
 */
enum StandardJsonFormat: JsonFormat {

    enum Keys: String, JsonCodingKeys {
        case message
        case path
        case value
        case type
        case samples
        case count
        case depth
        case time
        case end
        case id
        case children
    }

    static func tag(for type: MessageType) -> String {
        type.rawValue
    }

    static func messageType(from tag: String) -> MessageType? {
        MessageType(rawValue: tag)
    }

    static func tag(for type: ValueType) -> String {
        type.rawValue
    }

    static func valueType(from tag: String) -> ValueType? {
        ValueType(rawValue: tag)
    }
}
