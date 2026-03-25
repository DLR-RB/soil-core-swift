import Foundation

/**
 A node in the data tree that contains binary data.
 */
public protocol DataStorageNode: AnyStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    func set(_ value: Data) -> any Request

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not binary data
     */
    func value() async -> Data?
}
