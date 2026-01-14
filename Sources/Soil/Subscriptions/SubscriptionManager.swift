
/// The depth of a subscription (may be nil)
private typealias Depth = Int?


final class SubscriptionManager<SubscriberId: Hashable> {

    /// An internal struct to store subscription and exclusion information for a node
    private struct Subscription {

        /// The maximum level up to which a subscriber wants the path
        var subscription: Depth?

        /// The maximum level up to which a subscriber ignores a path
        var exclusion: Depth?
    }

    // MARK: Node

    /// An internal class to store the subscriptions for a node in the path tree.
    private final class SubscriptionNode {

        var subscriptions: [SubscriberId : Subscription] = [:]

        /// The child nodes of this path
        var nodes: [PathComponent : SubscriptionNode] = [:]

        /// Indicate if the node does not contain a subscription or children
        ///
        /// - Note: This function does not check if child nodes are empty
        var isEmpty: Bool {
            subscriptions.isEmpty && nodes.isEmpty
        }

        /**
         Check if subscriptions exist for a subscriber in the tree of this node.
         - Returns: `true`, if one or more subscriptions exist.
         */
        func hasSubscriptions(for subscriber: SubscriberId) -> Bool {
            if let subscription = subscriptions[subscriber], subscription.subscription != nil {
                return true
            }
            for node in nodes.values {
                if node.hasSubscriptions(for: subscriber) {
                    return true
                }
            }
            return false
        }

        func subscribe(_ subscriber: SubscriberId, depth: Depth) {
            guard var subscription = subscriptions[subscriber] else {
                subscriptions[subscriber] = .init(subscription: depth)
                return
            }

            // 2. Set the new subscription
            subscription.subscription = depth

            // 3. Remove an exlusion if it is redundant
            if let exclusionDepth = subscription.exclusion, exclusionDepth == depth {
                subscription.exclusion = nil
            }
            subscriptions[subscriber] = subscription
        }

        /**
         Exclude a subscriber.

         If a subscription exists with the same depth, then the subscription is removed without adding an exclusion.
         - Parameter subscriber: The id of the subscriber
         - Parameter depth: The optional depth of the exclusion
         - Returns: `true`, if the exclusion was added, `false`, if an existing subscription was removed instead.
        */
        func exclude(_ subscriber: SubscriberId, depth: Int?) -> Bool {
            guard var subscription = subscriptions[subscriber] else {
                subscriptions[subscriber] = .init(exclusion: depth)
                return true
            }

            if let subscriptionDepth = subscription.subscription, subscriptionDepth == depth {
                subscriptions[subscriber] = nil
                return false
            }

            subscription.exclusion = depth
            subscriptions[subscriber] = subscription
            return true
        }

        func remove(subscriber: SubscriberId) {
            subscriptions[subscriber] = nil
            for child in nodes.values {
                child.remove(subscriber: subscriber)
            }
            // Remove unused child nodes
            // Since remove() is called recursively on the tree,
            // this will clear all empty paths in the tree from the leaves to the root
            for (component, child) in nodes where child.isEmpty {
                nodes[component] = nil
            }
        }
    }

    /// The root node of the path tree to store subscriptions
    private let root: SubscriptionNode

    init() {
        root = SubscriptionNode()
    }

    // MARK: Subscriptions

    /**
     Subscribe to a path.

     The subscription will be added for the path with the given depth.
     - If an exclusion exists with the same depth, then it is removed, otherwise it is kept

     Call ``exclude(_:for:depth:)`` with the same depth to remove the subscription.
     Call ``exclude(_:for:depth:)`` twice to establish an exclusion where the subscription was.

     Exclusions with a different depth are not touched, because they are deemed intentional to construct complex subscription patterns.
     A component may exclude a specific sub-tree before subscribing, or add additional exclusions and subscriptions on other levels.
     */
    func subscribe(_ subscriber: SubscriberId, to path: Path, depth: Int?) {
        let node = findOrCreateNode(at: path)
        node.subscribe(subscriber, depth: depth)
    }

    /**
     Exclude a path from a subscription.

     Exclusions only act on subscriptions of the same path or on subscriptions of ancestors.

     If a subscription exists with the same depth for the same path, then the subscription is removed without adding an exclusion.
     Call ``subscribe(_:to:depth:)`` with the same `depth` to remove the exclusion and add a subscription.
     - Parameter subscriber: The id of the subscriber
     - Parameter path: The path to exclude for the subscriber
     - Parameter depth: The optional depth of the exclusion
     - Returns: `true`, if the exclusion was added, `false`, if an existing subscription was removed instead.
     */
    @discardableResult
    func exclude(_ subscriber: SubscriberId, from path: Path, depth: Int?) -> Bool {
        let node = findOrCreateNode(at: path)
        return node.exclude(subscriber, depth: depth)
    }

    // MARK: Notifications

    /**
     Find all subscribers for a given path.
     - Parameter path: The path to query subscribers for
     - Returns: The set of subscribers interested in the path.
     */
    func subscribers(to path: Path) -> Set<SubscriberId> {
        // To find all subscribers, we move from the full path towards the root,
        // tracking all subscribers. At each level, we check for new subscriptions.

        // If we find an exclusion that applies down to the path level, then we ignore the subscriber
        // If we find a subscription down to the path, then we mark the subscriber as applicable
        // A subscriber that is either applicable or ignored, is not considered for the rest of the path to the root.
        let nodes = existingNodes(for: path)

        var subscribers: Set<SubscriberId> = [] // Found subscribers
        var exclusions: Set<SubscriberId> = [] // Found ignored subscribers

        // We start at the lowest existing node containing any subscriptions or inclusions,
        // and work our way up to the root
        var level = nodes.count - 1
        while level >= 0 {
            let node = nodes[level]
            // The relative level describes how many levels the full path is below the current node
            // This number can directly be compared to the depth of subscriptions and inclusions
            // to check if they are relevant
            let relativePathLevel = path.count - level

            for (subscriber, subscription) in node.subscriptions {
                // Ignore previously handled subscribers
                guard !subscribers.contains(subscriber) && !exclusions.contains(subscriber) else {
                    continue
                }

                // 1. If the current node contains an exclusion reaching down to the path level
                // then we ignore the subscriber
                if let relativeExclusion = subscription.exclusion,
                   relativeExclusion.isNilOrNotSmaller(than: relativePathLevel) {
                    exclusions.insert(subscriber)
                    continue
                }
                // 2. If the current node contains a matching subscription, then the subscriber is applicable
                if let relativeSubscription = subscription.subscription,
                   relativeSubscription.isNilOrNotSmaller(than: relativePathLevel) {
                    subscribers.insert(subscriber)
                    continue
                }
                // The subscriptions don't apply to this path, so ignore them
            }
            // Advance to the next higher node
            level -= 1
        }

        // After reaching the root node, we have all applicable subscribers
        return subscribers
    }

    // MARK: Management

    /**
     Remove all subscriptions and exclusions of a subscriber
     */
    func remove(subscriber: SubscriberId) {
        // Note: The root node is always present
        // even if all child nodes may be removed
        root.remove(subscriber: subscriber)
    }

    /**
     Check if there is any subscription registered for the subscriber.
     - Returns: `true`, if one or more subscriptions exist for the id
     */
    func hasSubscriptions(for subscriber: SubscriberId) -> Bool {
        root.hasSubscriptions(for: subscriber)
    }

    // MARK: Helper

    private func findOrCreateNode(at path: Path) -> SubscriptionNode {
        var node = root
        for component in path {
            if let child = node.nodes[component] {
                node = child
            } else {
                let child = SubscriptionNode()
                node.nodes[component] = child
                node = child
            }
        }
        return node
    }

    private func existingNodes(for path: Path) -> [SubscriptionNode] {
        var result = [root]
        var last = root
        for component in path {
            guard let child = last.nodes[component] else {
                break
            }
            result.append(child)
            last = child
        }
        return result
    }
}
