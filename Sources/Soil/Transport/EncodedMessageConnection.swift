import Foundation

/**
 A connection to a component that transmits and receives encoded messages.
 */
public protocol EncodedMessageConnection: Connection, EncodedMessageDistributor, Sendable {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    func send(message: Data) -> any Request
}

extension EncodedMessageConnection {

    /**
     Convert this connection to a message connection using the provided encoding
     - Parameter encoding: The encoding to use for messages over the connection.
     - Parameter logger: The logger to use for the encoding step
     - Returns: The message connection using the encoding over the binary connection.
     */
    public func apply(encoding: any MessageEncoding, logger: Logger? = nil) async -> MessageConnection {
        await DecodedConnection(wrapping: self, encoding: encoding, logger: logger)
    }
}
