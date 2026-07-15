import Foundation

/**
 A type that can receive messages.
 */
public protocol EncodedMessageReceiver: AnyObject, Sendable {

    /**
     Process a received message.

     Each call to this function contains exactly the bytes of one encoded message.
     - Parameter data: The encoded message to process
     */
    @discardableResult
    func accept(encodedMessage data: Data) -> any Request
}