import Foundation

/**
 A type that can receive messages.
 */
public protocol EncodedMessageReceiver: AnyObject, Sendable {

    /**
     Process a received message.
     - Parameter data: The encoded message to process
     */
    func didReceive(encodedMessage data: Data) async
}