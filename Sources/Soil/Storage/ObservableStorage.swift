
/**
 A wrapper to make a storage observable
 */
public actor ObservableStorage {

    private let storage: any Storage

    /// The subscriptions, indexed by their id
    private let subscriptions = SubscriptionTree()

    /// Subscription data receiver
    private var receiver: (any Receiver)?

    public init(wrapping storage: any Storage) {
        self.storage = storage
    }

    private func receiveInternal(_ tree: any SampleTree, for path: Path) async {
        guard !tree.isEmpty else {
            return
        }

        // Store the data, wait for completion so that the receive of this class
        // works as expected
        await storage.accept(tree, for: path).wait()

        // Forward the data to the subscription receiver, if needed
        await distribute(tree: tree, path: path)
    }

    private func includeInternal(_ path: Path, depth: Int?) {
        subscriptions.include(path, depth: depth)
    }

    private func excludeInternal(_ path: Path, depth: Int?) {
        subscriptions.exclude(path, depth: depth)
    }

    private func deleteRulesInternal(_ path: Path, depth: Int?) {
        subscriptions.deleteRules(at: path, depth: depth)
    }
}

extension ObservableStorage: Observable {

    /**
     Set the receiver for subscription data
     - Parameter receiver: The receiver of data matching the subscription rules
     - Returns: A request to optionally wait for completion
     */
    @discardableResult
    public nonisolated func setReceiver(_ receiver: (any Receiver)?) -> any Request {
        AsyncRequest {
            await self.setReceiverSynchronized(receiver)
        }
    }

    private func setReceiverSynchronized(_ receiver: (any Receiver)?) {
        self.receiver = receiver
    }

    /**
     Get the receiver for matching data.
     - Returns: The receiver, if set
     */
    public func getReceiver() -> (any Receiver)? {
        receiver
    }

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the inclusion
     */
    @discardableResult
    public nonisolated func include(_ path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.includeInternal(path, depth: depth)
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
            await self.excludeInternal(path, depth: depth)
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
            await self.deleteRulesInternal(path, depth: depth)
        }
    }

    /**
     Check if a particular path is covered by the current subscription rules.
     - Parameter path: The path to check against the subscription rules
     - Returns: `true`, if the path matches
     */
    public func isSubscribed(to path: Path) -> Bool {
        subscriptions.isSubscribed(to: path)
    }

    /**
     Use the subscription rules to remove all excluded parts of a tree.
     - Parameter tree: The original tree to strip
     - Parameter path: The path of the tree in relation to the subscription tree
     - Returns: The reduced tree, if any inclusion rules match, otherwise `null`
     */
    public func reduce(_ tree: any SampleTree, at path: Path) -> (any SampleTree)? {
        subscriptions.reduce(tree, for: path)
    }
}

extension ObservableStorage: Storage {

    /**
     Receive a tree for a path.
     - Parameter tree: The tree to store.
     - Parameter path: The path associated with the samples
     */
    @discardableResult
    public nonisolated func accept(_ tree: any SampleTree, for path: Path) -> Request {
        AsyncRequest {
            await self.receiveInternal(tree, for: path)
        }
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
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> Request {
        storage.delete(path: path, from: start, to: end, depth: depth)
    }
}