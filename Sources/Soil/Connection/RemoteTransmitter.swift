import Foundation

/**
 Process data from a remote component that transmits data
 */
public actor RemoteTransmitter {

    /// The connection to receive messages
    public let connection: any MessageConnection

    /// The object managing active message batches
    private let batches: RemoteDataCollector

    /**
     Create an interface to a remote transmitter.
     - Parameter receiver: The receiver to get data from the remote
     - Parameter connection: The connection to the component via a transport layer.
     - Parameter batchTimeout: The number of seconds to wait for incoming data batches
     */
    public init(receiver: any Receiver, connection: any MessageConnection, batchTimeout: TimeInterval = 30.0) async {
        self.connection = connection
        self.batches = .init(receiver: receiver, batchTimeout: batchTimeout)

        // Register to receive messages from the component
        await connection.setReceiver(batches)
    }

    /**
     Set the receiver for data received over the connection.
     - Parameter receiver: The receiver of the data coming in over this connection.
     */
    public func setReceiver(_ receiver: any Receiver) async {
        await batches.setReceiver(receiver)
    }

    /**
     Get the receiver of incoming messages of this connection.
     */
    public func getReceiver() async -> any Receiver {
        return await batches.getReceiver()
    }
}
