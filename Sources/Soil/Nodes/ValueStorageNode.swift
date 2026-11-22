/**
 A node in the data tree that contains values of a specific type.

 Create typed nodes using ``Storage/node(at:as:)`` or ``StorageNode/typed(as:)``:

 ```swift
 let temperature = storage.node(at: ["sensor", "temperature"], as: Double.self)
 try temperature.set(21.5)
 let current = await temperature.value() // Double?
 ```
 */
public struct ValueStorageNode<T: ValueConvertible>: Sendable {

    /// The untyped node
    public let node: StorageNode

    /// The path of the node in the tree
    public var path: Path {
        node.path
    }

    /**
     Create a typed node.
     - Parameter node: The untyped node to wrap
     */
    public init(node: StorageNode) {
        self.node = node
    }

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     - Throws: An error, if the value can't be converted to a SOIL value
     */
    @discardableResult
    public func set(_ value: T) throws -> any Request {
        try node.set(value)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, if no value exists,
       or the current value can't be converted to the type
     */
    public func value() async -> T? {
        await node.value(as: T.self)
    }
}

extension ValueStorageNode: AnyStorageNode {

    @discardableResult
    public func setNull() -> any Request {
        node.setNull()
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
        node.delete(from: start, to: end, depth: depth)
    }

    /**
     Create a generic storage node for a child of this node.
     - Parameter name: The name of the child.
     - Returns: The node representing the child.
     */
    public func child(named component: String) -> StorageNode {
        node.child(named: component)
    }
}
