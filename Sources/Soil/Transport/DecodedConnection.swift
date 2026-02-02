import Foundation

/**
 Apply an encoding to a binary connection to create a message-based connection.
 */
public actor DecodedConnection {

    /// The encoding to use for the messages
    private let encoding: any MessageEncoding

    /// The binary connection over which encoded messages are exchanged
    private let connection: any BinaryConnection

    /// The callback function for new messages
    private var callback: ((Message) -> Void)?

    /**
     Wrap a binary connection with an encoding.
     - Parameter connection: The binary connection to apply the encoding to
     - Parameter encoding: The encoding used for the binary connection.
     */
    public init(wrapping connection: any BinaryConnection, encoding: any MessageEncoding) {
        self.connection = connection
        self.encoding = encoding

        connection.onReceive { [weak self] data in
            guard let self else {
                return
            }
            Task {
                await self.didReceive(data)
            }
        }
    }

    /**
     Set the callback function (actor-isolated) to forward messages to the connection.
     - Parameter callback: The closure to call with new messages.
     */
    private func setCallback(_ callback: @escaping @Sendable (Message) -> Void) {
        self.callback = callback
    }

    /**
     Process binary messages received over the connection.

     Attempts to decode the message contained in the data and forwards it to the message connection.
     */
    private func didReceive(_ data: Data) {
        guard let callback else {
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
        callback(message)
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
     Register a callback to receive messages from the component
     - Parameter callback: The closure called with new messages.
     - Note: the callback is saved asynchronously, so it is not immidatelly available.
     */
    public nonisolated func onReceive(_ callback: @escaping @Sendable (Message) -> Void) {
        Task {
            await self.setCallback(callback)
        }
    }
}