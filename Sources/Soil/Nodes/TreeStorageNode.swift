/**
 A node in the data tree that contains a tree of a specific type.

 The value is spread over the node and its children, as defined by ``SampleTreeConvertible``.

 Create tree nodes using ``Storage/treeNode(at:as:)`` or ``StorageNode/treeNode(as:)``:

 ```swift
 let robot = storage.treeNode(at: ["robot"], as: Robot.self)
 try robot.set(Robot(name: "R2", position: .init(x: 1, y: 2)))
 let current = await robot.value() // Robot?
 ```
 */
public struct TreeStorageNode<T: SampleTreeConvertible>: Sendable {

    /// The untyped node
    public let node: StorageNode

    /// The path of the node in the tree
    public var path: Path {
        node.path
    }

    /**
     Create a tree node.
     - Parameter node: The untyped node to wrap
     */
    public init(node: StorageNode) {
        self.node = node
    }

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node and its children
     - Parameter timestamp: The timestamp set for all samples of the tree that don't have one
     - Returns: A request to wait for completion
     - Throws: An error, if the value can't be converted to a SOIL tree
     */
    @discardableResult
    public func set(_ value: T, at timestamp: Timestamp? = nil) throws -> any Request {
        try node.accept(tree: value, at: timestamp)
    }

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, if the current tree
       can't be converted to the type
     */
    public func value() async -> T? {
        await node.currentTree(as: T.self)
    }
}

extension TreeStorageNode: AnyStorageNode {

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
