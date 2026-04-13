
/**
 A wrapper to make a storage observable
 */
public actor ObservableStorage {

    private let storage: any Storage

    /// The subscriptions, indexed by their id
    private var subscriptions: [Int : StorageSubscription] = [:]

    private var lastId = 0

    public init(wrapping storage: any Storage) {
        self.storage = storage
    }

    private func receiveInternal(_ tree: any SampleTree, for path: Path) async {
        guard !tree.isEmpty else {
            return
        }

        // Store the data, wait for completion so that the receive of this class
        // works as expected
        await storage.receive(tree, for: path).wait()

        // Notify the subscriptions, but don't wait for each one to complete
        for subscription in subscriptions.values {
            guard await subscription.isSubscribed(to: path) else {
                continue
            }
            // Don't wait for completion here
            await subscription.receive(tree, for: path)
        }
    }

    private func nextId() -> Int {
        lastId += 1
        return lastId
    }

    private func cancel(subscription id: Int) {
        subscriptions[id] = nil
    }
}

extension ObservableStorage: Observable {

    /**
     Create a subscription for a receiver
     - Parameter receiver: The receiver of data matching the subscription
     - Returns: The subscription for the receiver
     */
    public func subscribe(_ receiver: any Receiver) -> Subscription {
        let id = nextId()
        let subscription = StorageSubscription(receiver: receiver) {
            Task {
                await self.cancel(subscription: id)
            }
        }
        subscriptions[id] = subscription
        return subscription
    }
}

extension ObservableStorage: Storage {

    /**
     Receive a tree for a path.
     - Parameter tree: The tree to store.
     - Parameter path: The path associated with the samples
     */
    @discardableResult
    public nonisolated func receive(_ tree: any SampleTree, for path: Path) -> Request {
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