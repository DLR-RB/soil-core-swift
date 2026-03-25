
/**
 A node in the data tree that contains doubles.
 */
public protocol DoubleStorageNode: AnyStorageNode {

    /**
     Set the node to a value.
     - Parameter value: The new value to set for this node
     - Returns: A request to wait for completion
     */
    @discardableResult
    func set(_ value: Double) -> any Request

    /**
     Get the current value of the node.

     - Returns: The current value, or `nil`, of no value exists,
       or the current value is not a double
     */
    func value() async -> Double?
}
