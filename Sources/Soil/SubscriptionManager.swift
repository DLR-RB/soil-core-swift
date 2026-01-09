
private typealias Depth = Int?


final class SubscriptionManager<SubscriberId: Hashable> {

    /// An internal struct to store subscription and exclusion information for a node
    private struct Subscription {

        /// The maximum level up to which a subscriber wants the path
        var subscription: Depth?

        /// The maximum level up to which a subscriber ignores a path
        var exclusion: Depth?

    }

    /// An internal class to store the subscriptions for a node in the path tree.
    private final class SubscriptionNode {

        var subscriptions: [SubscriberId : Subscription] = [:]

        /// The child nodes of this path
        var nodes: [PathComponent : SubscriptionNode] = [:]

        var isEmpty: Bool {
            subscriptions.isEmpty && nodes.isEmpty
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
        // 1. Find the correct node in the tree
        let node = findOrCreateNode(at: path)

        guard var subscription = node.subscriptions[subscriber] else {
            node.subscriptions[subscriber] = .init(subscription: depth)
            return
        }

        // 2. Set the new subscription
        subscription.subscription = depth

        // 3. Remove an exlusion if it is redundant
        if let exclusionDepth = subscription.exclusion, exclusionDepth == depth {
            subscription.exclusion = nil
        }
        node.subscriptions[subscriber] = subscription
    }

    /**
     Exclude a path from a subscription.

     Exclusions only act on subscriptions of the same path or on subscriptions of ancestors.

     If a subscription exists with the same depth for the same path, then the subscription is removed without adding an exclusion.
     Call ``subscribe(_:to:depth:)`` with the same `depth` to remove the exclusion and add a subscription.
     */
    func exclude(_ subscriber: SubscriberId, from path: Path, depth: Int?) {
        // 1. Find the correct node in the tree
        let node = findOrCreateNode(at: path)

        guard var subscription = node.subscriptions[subscriber] else {
            node.subscriptions[subscriber] = .init(exclusion: depth)
            return
        }

        // 2. Remove the subscription if needed
        if let subscriptionDepth = subscription.subscription, subscriptionDepth == depth {
            node.subscriptions[subscriber] = nil
            return
        }

        // 3. Set the exclusion
        subscription.exclusion = depth
        node.subscriptions[subscriber] = subscription
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
        remove(subscriber: subscriber, from: root)
    }

    private func remove(subscriber: SubscriberId, from node: SubscriptionNode) {
        node.subscriptions[subscriber] = nil
        for child in node.nodes.values {
            remove(subscriber: subscriber, from: child)
        }
        // Remove unused nodes
        for (component, child) in node.nodes where child.isEmpty {
            node.nodes[component] = nil
        }
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
        for component in path {
            guard let child = result.last!.nodes[component] else {
                break
            }
            result.append(child)
        }
        return result
    }
}
