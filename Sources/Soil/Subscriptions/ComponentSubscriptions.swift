
/**
 Handles component-internal subscriptions via callbacks

 This class allows other types to subscribe to paths with a callback,
 and informs all subscribers about new samples for paths.
 */
final class ComponentSubscriptions {

    /// The root node in the tree where the rest of the tree will be constructed
    private let root = SubscriptionTree()

    /// The callbacks for subscriptions, indexed by the subscription id.
    private var callbacks: [Int : (_ subscription: Int, _ path: Path, _ sample: Sample) -> Void] = [:]

    /**
     Create a new subscription manager.
     */
    init() { }

    /**
     Inform all subscribers about a new sample for a path via the registered callbacks.
     - Parameter samples: The samples to send to subscribers
     - Parameter path: The path associated with the sample
     - Returns: The number of subscribers that were notified about the samples.
     */
    @discardableResult
    func notifySubscribers(about samples: [Sample], at path: Path) -> Int {
        var notified = 0
        for subscription in subscriptions(to: path) {
            guard let callback = callbacks[subscription] else {
                // Attempt to restore a reasonable state by removing the subscription
                // but this case should not actually occur
                delete(subscription: subscription)
                continue
            }
            for sample in samples {
                callback(subscription, path, sample)
            }
            notified += 1
        }
        return notified
    }

    /**
     Inform all subscribers about a new sample for a path via the registered callbacks.
     - Parameter sample: The sample to send to subscribers
     - Parameter path: The path associated with the sample
     - Returns: The number of subscribers that were notified about the sample.
     */
    @discardableResult
    func notifySubscribers(about sample: Sample, at path: Path) -> Int {
        notifySubscribers(about: [sample], at: path)
    }

    /**
     Find all subscriptions for a given path.
     - Parameter path: The path to query subscriptions for
     - Returns: The set of subscribption ids interested in the path.
     */
    func subscriptions(to path: Path) -> Set<Int> {
        root.subscriptions(to: path)
    }

    /**
     Check if there is any rule registered for the subscription.
     - Parameter subscription: The id of the subscription to check
     - Returns: `true`, if one or more subscription rules exist for the id
     */
    func hasSubscriptionRules(for subscription: Int) -> Bool {
        root.hasSubscriptionRules(for: subscription)
    }
}

extension ComponentSubscriptions: Observable {

    /**
     Create a subscription for future changes to data.
     - Parameter subscription: The subscription id to add
     - Parameter callback: The closure to call with updates in the future.
     - Parameter path: The path of the changed data
     - Parameter sample: The changed data at the path
     - Note: A previous subscription with the same id will be replaced by the new one, and all previous rules will be deleted
     */
    public func create(_ subscription: Int, callback: @escaping (_ subscription: Int, _ path: Path, _ sample: Sample) -> Void) {
        if hasSubscription(subscription) {
            deleteAllRules(for: subscription)
        }
        callbacks[subscription] = callback
    }

    /**
     Include a path in a subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Parameter subscription: The id of the subscription
     */
    public func include(_ path: Path, depth: Int?, in subscription: Int) {
        guard hasSubscription(subscription) else { return }
        root.findOrCreateNode(at: path).include(depth: depth, in: subscription)
    }

    /**
     Exclude a path from a subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Parameter subscription: The id of the subscription
     */
    public func exclude(_ path: Path, depth: Int?, from subscription: Int) {
        guard hasSubscription(subscription) else { return }
        root.findOrCreateNode(at: path).exclude(depth: depth, in: subscription)
    }

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Parameter subscription: The id of the subscription to target.
     */
    public func deleteRules(at path: Path, depth: Int?, for subscription: Int) {
        guard hasSubscription(subscription) else { return }
        root.deleteRules(for: subscription, depth: depth)
    }

    /**
     Delete all rules and the callback for a subscription
     - Parameter subscription: The id of the subscription to delete.
     */
    public func delete(subscription: Int) {
        deleteAllRules(for: subscription)
        callbacks[subscription] = nil
    }

    /**
     Indicate if a callback for the subscription exists.
     - Parameter subscription: The id of the subscription
     - Returns: `true`, if a callback exists.
     */
    public func hasSubscription(_ subscription: Int) -> Bool {
        callbacks[subscription] != nil
    }
}

extension ComponentSubscriptions: CustomStringConvertible {

    var description: String {
        "Subscriptions(\(root.numberOfNodes) nodes, \(root.numberOfRules) rules)"
    }
}

extension ComponentSubscriptions: DebugConvertible {

    func described(indent: String) -> [String] {
        var lines: [String] = []
        lines.append("Subscriptions (\(callbacks.count)): \(callbacks.keys.sorted().map { "\($0)" }.joined(separator: ", "))")
        lines.append("Root")
        lines.append(contentsOf: root.described(indent: "  ").map { indent + $0 })
        return lines
    }
}