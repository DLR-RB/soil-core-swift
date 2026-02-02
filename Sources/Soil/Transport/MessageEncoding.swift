import Foundation

/**
 An interface to convert messages for the transport layer.
 */
public protocol MessageEncoding {

    /**
     Convert a message to binary data for transmission.
     - Parameter message: The message to encode
     - Returns: The binary data of the encoded message
     - Throws: An error, if the message could not be encoded
     */
    func encode(_ message: Message) throws -> Data

    /**
     Extract a message from binary data.
     - Parameter data: The encoded message
     - Returns: The decoded message
     - Throws: An error, if the message could not be decoded
     */
    func decode(_ data: Data) throws -> Message
}