
/**
 Expose an observable storage over an interface.

 It internally creates a ``HostedObservable`` and ``HostedStorage``,
 and distributes messages from the component to both objects.
 */
public actor HostedObservableStorage {

    /// The exposed observable managing the subscriptions
    private let observable: HostedObservable

    /// The exposed storage
    private let storage: HostedStorage

    /// The connection to the remote
    public var connection: Connection {
        observable.connection
    }

    /**
     Host an observable storage over a connection.
     - Parameter observable: The observable storage to expose.
     - Parameter connection: The connection over which to expose the observable storage
     */
    public init(host observable: any Observable & Storage, through connection: any MessageConnection) async {
        // Note: Currently incoming data will be echoed back if the remote subscribes to the path
        // This could lead to infinite loops
        self.observable = await .init(hosting: observable, through: connection)
        self.storage = await .init(hosting: observable, through: connection)

        // Receive messages in this class, and redistribute to the parts
        await connection.setReceiver(self)
    }

    /// The number of subscriptions currently registered by the component
    public func numberOfSubscriptions() async -> Int {
        await observable.numberOfSubscriptions
    }
}

// MARK: Message receiver

extension HostedObservableStorage: MessageReceiver {

    /**
     Insertion point for messages received over the connection.

     Subscription messages are forwarded to the contained observable,
     while data, requests, and deletions are forwarded to the wrapped storage.
     - Parameter message: The message received over the connection.
     - Note: This function is called automatically be the connection, and should not be called manually.
     */
    public func didReceive(message: Message) async {
        switch message.type {
        case .data, .request, .deletionRequest:
            await storage.didReceive(message: message)
        case .subscriptionInclusion, .subscriptionExclusion, .subscriptionDeletion:
            await observable.didReceive(message: message)
        }
    }
}

// MARK: Storage

extension HostedObservableStorage: Storage {

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
     - Returns: A request that can be used to wait until completion
     */
    @discardableResult
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        storage.delete(path: path, from: start, to: end, depth: depth)
    }
}
