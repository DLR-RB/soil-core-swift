
/**
 Create a transmitter to send data to a remote component
 */
public actor HostedTransmitter {

    /// The connection to use to transmit the data
    private let connection: any MessageConnection

    /**
     Create a transmitter over a connection.
     - Parameter connection: The connection over which the messages should be sent
     */
    public init(connection: any MessageConnection) {
        self.connection = connection
    }
}

extension HostedTransmitter: Receiver {

    /**
     Receive a request to store a tree for a path.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the data is stored, use ``commit()``
     - SeeAlso: ``commit(_:for:)``
     */
    @discardableResult
    public nonisolated func receive(_ tree: SampleTree, for path: Path) -> any Request {
        connection.send(tree, for: path)
    }
}

