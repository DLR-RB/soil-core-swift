
/**
 Process data from a remote component that transmits data
 */
public actor RemoteTransmitter {

    /// The receiver injesting updates from the remote component
    private let receiver: any Receiver

    /// The connection to receive messages
    public let connection: any MessageConnection

    /**
     Create an interface to a remote transmitter.
     - Parameter receiver: The receiver to get data from the remote
     - Parameter connection: The connection to the component via a transport layer.
     */
    public init(receiver: any Receiver, connection: any MessageConnection) async {
        self.receiver = receiver
        self.connection = connection

        // Register to receive messages from the component
        await connection.setReceiver(self)
    }
}

// MARK: Response handling

extension RemoteTransmitter: MessageReceiver {

    /**
     Callback to receive messages from the remote component.
     - Parameter message: The message received over the connection
     - Note: This function is called automatically by the connection, and should not be called manually.
     */
    public func didReceive(message: Message) {
        guard message.hasSamples else {
            return
        }
        receiver.receive(message.allSamples, for: message.path)
    }
}