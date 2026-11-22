import Foundation

/**
 An encoding that represents messages as compact JSON objects
 */
public final class CompactJsonEncoding: Sendable {

    /// Create a JSON encoding layer.
    public init() {

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
        try JsonCoding<CompactJsonFormat>.encode(message)
    }

    /**
     Extract a message from JSON data.
     - Parameter data: The JSON message data
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    public func decode(_ data: Data) throws -> Message {
        try JsonCoding<CompactJsonFormat>.decode(data)
    }
}

/**
 The compact JSON format, using single-letter keys and integer type identifiers.
 */
enum CompactJsonFormat: JsonFormat {

    static func key(for field: JsonField) -> String {
        switch field {
            case .message: "m"
            case .path: "p"
            case .value: "v"
            case .type: "h"
            case .samples: "s"
            case .count: "c"
            case .depth: "d"
            case .time: "t"
            case .end: "e"
            case .id: "i"
            case .children: "n"
        }
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
            case .path: 5
            case .list: 6
            case .map: 7
        }
    }

    static func valueType(from tag: Int) -> ValueType? {
        switch tag {
            case 0: .null
            case 1: .integer
            case 2: .double
            case 3: .string
            case 4: .data
            case 5: .path
            case 6: .list
            case 7: .map
            default: nil
        }
    }
}
