
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

        await connection.setReceiver(self).wait()
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

extension RemoteObservableStorage: Distributor {

    /**
     Set the receiver for subscription data
     - Parameter receiver: The receiver of data matching the subscription rules
     - Returns: A request to optionally wait for completion
     */
    @discardableResult
    public nonisolated func setReceiver(_ receiver: (any Receiver)?) -> any Request {
        observable.setReceiver(receiver)
    }

    /**
     Get the receiver for matching data.
     - Returns: The receiver, if set
     */
    public func getReceiver() async -> (any Receiver)? {
        await observable.getReceiver()
    }
}

extension RemoteObservableStorage: Observable {

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the inclusion
     */
    @discardableResult
    public nonisolated func include(_ path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.observable.include(path, depth: depth).wait()
        }
    }

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the exclusion
     */
    @discardableResult
    public nonisolated func exclude(_ path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.observable.exclude(path, depth: depth).wait()
        }
    }

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: A request to wait for completion of the deletion
     */
    @discardableResult
    public nonisolated func deleteRules(at path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.observable.deleteRules(at: path, depth: depth).wait()
        }
    }

    /**
     Check if a particular path is covered by the current subscription rules.
     - Parameter path: The path to check against the subscription rules
     - Returns: `true`, if the path matches
     */
    public func isSubscribed(to path: Path) async -> Bool {
        await observable.isSubscribed(to: path)
    }

    /**
     Use the subscription rules to remove all excluded parts of a tree.
     - Parameter tree: The original tree to strip
     - Parameter path: The path of the tree in relation to the subscription tree
     - Returns: The reduced tree, if any inclusion rules match, otherwise `null`
     */
    public func reduce(_ tree: any SampleTree, at path: Path) async -> (any SampleTree)? {
        await observable.reduce(tree, at: path)
    }
}

// MARK: Storage

extension RemoteObservableStorage: Storage {

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
    public nonisolated func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        storage.accept(tree, for: path)
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
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        storage.delete(path: path, from: start, to: end, depth: depth)
    }
}
