

/**
 A subscription made to a component
 */
public protocol Subscription {

    /**
     The receiver of updates that match the subscription
     */
    var receiver: (any Receiver)? { get set }

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: `true`, if the inclusion was registered
     */
    @discardableResult
    func include(_ path: Path, depth: Int?) -> Bool

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: `true`, if the exclusion was registered
     */
    @discardableResult
    func exclude(_ path: Path, depth: Int?) -> Bool

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: `true`, if the deletion was registered
     */
    @discardableResult
    func deleteRules(at path: Path, depth: Int?) -> Bool

    /**
     Cancel the subscription.
     - Returns: `true`, if the subscription was cancelled
     */
    @discardableResult
    func cancel() -> Bool
}

extension Subscription {

    /**
     Delete all rules, so that no data is received
     - Returns: `true`, if the deletion was registered
     */
    @discardableResult
    public func deleteAllRules() -> Bool {
        deleteRules(at: [], depth: nil)
    }
}