import Foundation

/**
 Apply an encoding to a binary connection to create a message-based connection.
 */
public actor DecodedConnection {

    /// The encoding to use for the messages
    private let encoding: any MessageEncoding

    /// The binary connection over which encoded messages are exchanged
    private let connection: any EncodedMessageConnection

    /// The receiver getting decoded messages
    private weak var receiver: (any MessageReceiver)?

    /**
     Wrap a binary connection with an encoding.
     - Parameter connection: The binary connection to apply the encoding to
     - Parameter encoding: The encoding used for the binary connection.
     */
    public init(wrapping connection: any EncodedMessageConnection, encoding: any MessageEncoding) async {
        self.connection = connection
        self.encoding = encoding

        await connection.setReceiver(self)
    }

    /**
     Process binary messages received over the connection.

     Attempts to decode the message contained in the data and forwards it to the message connection.
     */
    public func didReceive(encodedMessage data: Data) async {
        guard let receiver else {
            return
        }

        // Attempt to decode the message from the data
        let message: Message
        do {
            message = try encoding.decode(data)
        } catch {
            // TODO: Propagate error
            return
        }

        // Forward the decoded message to the component connection
        await receiver.didReceive(message: message)
    }

    /**
     Send a message (actor-isolated) over the connection.

     Attempts to encode the message using the encoding layer, and forwards it over the data connection.
     - Parameter message: The message to transmit
     */
    private func send(_ message: Message) async {
        let data: Data
        do {
            data = try encoding.encode(message)
        } catch {
            // TODO: Propagate error
            return
        }
        await connection.send(message: data).wait()
    }
}

extension DecodedConnection: EncodedMessageReceiver {

}

extension DecodedConnection: MessageConnection {

    /**
     Send a message to the component via the underlying transport layer.
     - Parameter message: The message to send
     - Returns: The transmission request, which can be awaited to wait for transmission.
     - Note: The returned request does not wait for message delivery, only transmission.
     */
    @discardableResult
    public nonisolated func send(message: Message) -> Request {
        AsyncRequest {
            await self.send(message)
        }
    }

    /**
     Set the receiver for messages produced by this connection.
     - Parameter receiver: The receiver of the messages coming in over this connection.
     */
    public func setReceiver(_ receiver: any MessageReceiver) {
        self.receiver = receiver
    }
}
