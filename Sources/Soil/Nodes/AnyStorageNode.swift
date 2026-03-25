
public protocol AnyStorageNode: Sendable {

    @discardableResult
    func setNull() -> any Request

    /**
     Delete data from the node.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Returns: A request that can be used to wait until completion
     */
    @discardableResult
    func delete(from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request

    /**
     Create a generic storage node for a child of this node.
     - Parameter name: The name of the child.
     - Returns: The node representing the child.
     */
    func child(named component: String) -> StorageNode
}