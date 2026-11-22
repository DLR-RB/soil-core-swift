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
    public func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        storage.accept(tree, for: self.path + path)
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
        storage.accept(Value.null, for: path)
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

// MARK: Values

extension StorageNode {

    /**
     Set the node to a SOIL value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: Value) -> any Request {
        storage.accept(value, for: path)
    }

    /**
     Set the node to a path value.

     - Note: Since `Path` is an array of strings, it would otherwise be stored as a `.list`.
     - Parameter value: The new path to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func set(_ value: Path) -> any Request {
        storage.accept(.path(value), for: path)
    }

    /**
     Set the node to a value, after converting it to a SOIL value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     - Throws: An error, if the value can't be converted to a SOIL value
     */
    @discardableResult
    // Disfavored, so that literals use the non-throwing `Value` overload
    @_disfavoredOverload
    public func set(_ value: some ValueConvertible) throws -> any Request {
        storage.accept(try value.soilValue, for: path)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, if no value exists
     */
    public func value() async -> Value? {
        await storage.currentValue(for: path)
    }

    /**
     Get the current value of the node, converted to a specific type.
     - Parameter type: The type to convert the value to
     - Returns: The current value, or `nil`, if no value exists,
       or the current value can't be converted to the type
     */
    public func value<T: ValueConvertible>(as type: T.Type = T.self) async -> T? {
        await storage.currentValue(for: path, as: type)
    }

    /**
     Create a node which only accepts values of a specific type.
     - Parameter type: The type of the node values
     - Returns: The typed node for the same path
     */
    public func typed<T: ValueConvertible>(as type: T.Type = T.self) -> ValueStorageNode<T> {
        ValueStorageNode(node: self)
    }

    /**
     Create a typed storage node for a child of this node.
     - Parameter component: The name of the child.
     - Parameter type: The type of the node values
     - Returns: The typed node representing the child.
     */
    public func child<T: ValueConvertible>(named component: String, as type: T.Type = T.self) -> ValueStorageNode<T> {
        child(named: component).typed(as: type)
    }
}

// MARK: Trees

extension StorageNode {

    /**
     Create a node which only accepts trees of a specific type.
     - Parameter type: The type of the node trees
     - Returns: The tree node for the same path
     */
    public func treeNode<T: SampleTreeConvertible>(as type: T.Type = T.self) -> TreeStorageNode<T> {
        TreeStorageNode(node: self)
    }

    /**
     Create a tree storage node for a child of this node.
     - Parameter component: The name of the child.
     - Parameter type: The type of the node trees
     - Returns: The tree node representing the child.
     */
    public func treeChild<T: SampleTreeConvertible>(named component: String, as type: T.Type = T.self) -> TreeStorageNode<T> {
        child(named: component).treeNode(as: type)
    }
}

extension Storage {

    /**
     Create a node to access the data at a path.
     - Parameter path: The path of the node in the tree
     - Returns: The node for the path
     */
    public func node(at path: Path) -> StorageNode {
        StorageNode(storage: self, path: path)
    }

    /**
     Create a node to access the data at a path with a specific type.
     - Parameter path: The path of the node in the tree
     - Parameter type: The type of the node values
     - Returns: The typed node for the path
     */
    public func node<T: ValueConvertible>(at path: Path, as type: T.Type = T.self) -> ValueStorageNode<T> {
        node(at: path).typed(as: type)
    }

    /**
     Create a node to access the tree at a path with a specific type.
     - Parameter path: The path of the node in the tree
     - Parameter type: The type of the node trees
     - Returns: The tree node for the path
     */
    public func treeNode<T: SampleTreeConvertible>(at path: Path, as type: T.Type = T.self) -> TreeStorageNode<T> {
        node(at: path).treeNode(as: type)
    }
}
