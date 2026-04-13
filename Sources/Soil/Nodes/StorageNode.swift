import Foundation

/**
 A node in a data tree for a specific path.

 This node can also be viewed as a storage,
 except that it maps all operations to a sub-tree.
 */
public struct StorageNode: Sendable {

    private let storage: any Storage

    /// The path of the node in the tree
    public let path: Path

    /**
     Create an interface to a node in a storage at a path.
     - Parameter storage: The storage to wrap
     - Parameter path: The path of the node in the tree
     */
    public init(storage: any Storage, path: Path) {
        self.storage = storage
        self.path = path
    }
}

extension StorageNode: Provider {

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
        await storage.tree(for: self.path + path, from: start, to: end, depth: depth, limitPerNode: limitPerNode)
    }
}

extension StorageNode: Receiver {

    /**
     Receive a request to ingest a tree for a path.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.

     - Parameter tree: The tree to ingest.
     - Parameter path: The path of the root node of the provided tree
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    public func receive(_ tree: any SampleTree, for path: Path) -> any Request {
        storage.receive(tree, for: self.path + path)
    }
}

extension StorageNode: Storage {

    /**
     Delete data from the storage.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Returns: A request that can be used to wait until completion
     */
    @discardableResult
    public func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        storage.delete(path: self.path + path, from: start, to: end, depth: depth)
    }
}

extension StorageNode: AnyStorageNode {

    @discardableResult
    public func setNull() -> any Request {
        storage.receive(Value.null, for: path)
    }

    /**
     Delete data from the node.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Returns: A request that can be used to wait until completion
     */
    @discardableResult
    public func delete(from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        storage.delete(path: path, from: start, to: end, depth: depth)
    }

    /**
     Create a generic storage node for a child of this node.
     - Parameter name: The name of the child.
     - Returns: The node representing the child.
     */
    public func child(named component: String) -> StorageNode {
        StorageNode(storage: storage, path: path + [component])
    }
}

extension StorageNode: StringStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: String) -> any Request {
        storage.receive(.string(value), for: path)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not a string
     */
    public func value() async -> String? {
        await storage.currentValue(for: path)?.stringValue
    }
}

extension StorageNode: IntStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: Int) -> any Request {
        storage.receive(.integer(value), for: path)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not an integer
     */
    public func value() async -> Int? {
        await storage.currentValue(for: path)?.integerValue
    }
}

extension StorageNode: DoubleStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: Double) -> any Request {
        storage.receive(.double(value), for: path)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not an double
     */
    public func value() async -> Double? {
        await storage.currentValue(for: path)?.doubleValue
    }
}

extension StorageNode: DataStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: Data) -> any Request {
        storage.receive(.data(value), for: path)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not binary data
     */
    public func value() async -> Data? {
        await storage.currentValue(for: path)?.dataValue
    }
}

extension StorageNode: PathStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: Path) -> any Request {
        storage.receive(.path(value), for: path)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not a path
     */
    public func value() async -> Path? {
        await storage.currentValue(for: path)?.pathValue
    }
}
