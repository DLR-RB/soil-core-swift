
/**
 Connect to a remote component that provides storage and observation.

 Internally manages a ``RemoteObservable`` and a ``RemoteStorage`` and distributes messages to both.
 */
public actor RemoteObservableStorage {

    /// The object managing the subscriptions to the remote
    private let observable: RemoteObservable

    /// The object managing the storage interface to the remote
    private let storage: RemoteStorage

    /// The connection to the remote
    public var connection: any Connection {
        observable.connection
    }

    /**
     Create a connection to an observable storage over a connection.
     - Parameter connection: The connection where the component is hosted.
     */
    public init(connection: any MessageConnection) async {
        observable = await .init(connection: connection)
        storage = await .init(connection: connection)

        await connection.setReceiver(self)
    }
}

// MARK: Message receiver

extension RemoteObservableStorage: MessageReceiver {

    /**
     Callback to receive messages from the remote component.
     - Parameter message: The message received over the connection
     - Note: This function is called automatically by the connection, and should not be called manually.
     */
    public func didReceive(message: Message) async {
        switch message.type {
        case .data:
            await storage.didReceive(message: message)
            await observable.didReceive(message: message)
        case .request:
            await storage.didReceive(message: message)
        case .deletionRequest:
            await storage.didReceive(message: message)
        case .subscriptionInclusion, .subscriptionDeletion, .subscriptionExclusion:
            await observable.didReceive(message: message)
        }
    }
}

// MARK: Observable

extension RemoteObservableStorage: Observable {

    /**
     Create a subscription for a receiver
     - Parameter receiver: The receiver of data matching the subscription
     - Returns: The subscription for the receiver
     */
    public func subscribe(_ receiver: any Receiver) async -> Subscription {
        await observable.subscribe(receiver)
    }
}

// MARK: Storage

extension RemoteObservableStorage: Storage {

    /**
     Receive samples for a path.

     Components may choose to ignore samples due to access rights or other reasons.
     - Parameter samples: The samples to store for the path.
     - Parameter path: The path associated with the samples
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    public nonisolated func receive(_ samples: [Sample], for path: Path) -> any Request {
        storage.receive(samples, for: path)
    }

    /**
     Receive a tree for a path.

     This is the singular function to inject data into a component.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
     */
    @discardableResult
    public nonisolated func receive(_ tree: SampleTree, for path: Path) -> Request {
        storage.receive(tree, for: path)
    }

    /**
     Read a data tree for a given path within a given interval.

     This is the singular function to serve all data retrieval needs.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     The `limitPerNode` is applied in sort order.

     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels below the path to include in the result
     - Parameter limitPerNode: The maximum number of values to return for each node of the tree (defaults to `nil`, e.g. no limit)
     - Returns: The tree with the given depth, limited to the maximum count per node, for the requested interval.
     - Note: This function is `async`, because providing the data may take some time.
       It could be retrieved over a network, from an otherwise slow database, or from other components.
     */
    public func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) async -> SampleTree {
        await storage.tree(for: path, from: start, to: end, depth: depth, limitPerNode: limitPerNode)
    }

    /**
     Delete data from the storage.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     */
    @discardableResult
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> Request {
        storage.delete(path: path, from: start, to: end, depth: depth)
    }
}