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
        try encoder.encode(message)
    }

    /**
     Extract a message from JSON data.
     - Parameter data: The JSON message data
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    public func decode(_ data: Data) throws -> Message {
        try decoder.decode(Message.self, from: data)
    }
}