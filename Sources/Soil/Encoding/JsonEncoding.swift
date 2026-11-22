import Foundation

/**
 An encoding that represents messages as JSON objects
 */
public final class JsonEncoding: Sendable {

    /// Create a JSON encoding layer.
    public init() {

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
        try JsonCoding<StandardJsonFormat>.encode(message)
    }

    /**
     Extract a message from JSON data.
     - Parameter data: The JSON message data
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    public func decode(_ data: Data) throws -> Message {
        try JsonCoding<StandardJsonFormat>.decode(data)
    }
}

/**
 The verbose JSON format, using descriptive keys and type names.
 */
enum StandardJsonFormat: JsonFormat {

    static func key(for field: JsonField) -> String {
        field.rawValue
    }

    static func field(for key: String) -> JsonField? {
        JsonField(rawValue: key)
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
