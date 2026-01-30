

/**
 A subscription made to a component
 */
public protocol Subscription: Sendable {

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the inclusion
     */
    @discardableResult
    func include(_ path: Path, depth: Int?) -> Request

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the exclusion
     */
    @discardableResult
    func exclude(_ path: Path, depth: Int?) -> Request

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: A request to wait for completion of the deletion
     */
    @discardableResult
    func deleteRules(at path: Path, depth: Int?) -> Request

    /**
     Cancel the subscription.
     - Returns: A request to wait for completion of the cancelation
     */
    @discardableResult
    func cancel() -> Request
}

extension Subscription {

    /**
     Delete all rules, so that no data is received
     - Returns: A request to wait for completion of the deletion
     */
    @discardableResult
    public func deleteAllRules() -> Request {
        deleteRules(at: [], depth: nil)
    }
}