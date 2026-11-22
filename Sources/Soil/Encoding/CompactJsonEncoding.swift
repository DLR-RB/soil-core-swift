import Foundation

/**
 An encoding that represents messages as compact JSON objects
 */
public final class CompactJsonEncoding: Sendable {

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

extension CompactJsonEncoding: MessageEncoding {

    /**
     Convert a message to JSON data for transmission.
     - Parameter message: The message to encode
     - Returns: The JSON data of the encoded message
     - Throws: An error, if the message could not be encoded
     */
    public func encode(_ message: Message) throws -> Data {
        // Wrap the message in a JSON message to use the custom encoding
        try encoder.encode(JsonCoding<CompactJsonFormat>.JsonMessage(message: message))
    }

    /**
     Extract a message from JSON data.
     - Parameter data: The JSON message data
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    public func decode(_ data: Data) throws -> Message {
        // Decode the wrapper to use the custom format
        try decoder.decode(JsonCoding<CompactJsonFormat>.JsonMessage.self, from: data).message
    }
}

/**
 The compact JSON format, using single-letter keys and integer type identifiers.
 */
enum CompactJsonFormat: JsonFormat {

    enum Keys: String, JsonCodingKeys {
        case message = "m"
        case path = "p"
        case value = "v"
        case type = "h"
        case samples = "s"
        case count = "c"
        case depth = "d"
        case time = "t"
        case end = "e"
        case id = "i"
        case children = "n"
    }

    static func tag(for type: MessageType) -> Int {
        switch type {
            case .data: 0
            case .request: 1
            case .deletionRequest: 2
            case .subscriptionInclusion: 3
            case .subscriptionExclusion: 4
            case .subscriptionDeletion: 5
        }
    }

    static func messageType(from tag: Int) -> MessageType? {
        switch tag {
            case 0: .data
            case 1: .request
            case 2: .deletionRequest
            case 3: .subscriptionInclusion
            case 4: .subscriptionExclusion
            case 5: .subscriptionDeletion
            default: nil
        }
    }

    static func tag(for type: ValueType) -> Int {
        switch type {
            case .null: 0
            case .integer: 1
            case .double: 2
            case .string: 3
            case .data: 4
            case .list: 5
            case .map: 6
        }
    }

    static func valueType(from tag: Int) -> ValueType? {
        switch tag {
            case 0: .null
            case 1: .integer
            case 2: .double
            case 3: .string
            case 4: .data
            case 5: .list
            case 6: .map
            default: nil
        }
    }
}
