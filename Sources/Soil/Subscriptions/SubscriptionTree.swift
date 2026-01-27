
/**
 A class to manage subscriptions of a single component

 The data is organized in a single tree of nodes, where each node stores information
 about its subscriptions, instead of a separate tree for each subscription id.
 This approach was chosen because it's then easier to check for subscriptions for a particular path,
 instead of iterating over all subscriptions and checking them.
 The downside is that removing all subscriptions for an id requires traversing the full tree once.
 */
final class SubscriptionTree {

    /// The nodes below this node, indexed by their name
    var children: [PathComponent : SubscriptionTree] = [:]

    /// The inclusions and exclusions at this node for each subscription
    var subscriptions: [Int : NodeSubscriptions] = [:]

    /**
     Create a new subscription tree
     */
    init() { }

    // MARK: Subscription queries

    /**
     Find all subscriptions for a given path.

     The function first finds all existing nodes along the path,
     and then traverses them from the bottom node to the root.
     If a node in the subscription tree has a matching rule
     (based on the relative depth), then the inclusion or exclusion is tracked.
     Already matched subscriptions (both inclusions and exclusions) are ignored
     for the remaining nodes. Once a the root, all matched inclusions are returned.

     - Parameter path: The path to query subscriptions for
     - Returns: The set of subscribption ids interested in the path.
     */
    func subscriptions(to path: Path) -> Set<Int> {
        // Traverse the tree to get the nodes along the path,
        // so that we can move towards the root
        let nodes = existingNodes(for: path)

        // The subscriptions that were matched, which can't be overwritten by higher-level rules
        var matchedSubscriptions: Set<Int> = []
        // The subscriptions that had matching exclude rules previously, which take precendence
        var ignoredSubscriptions: Set<Int> = []

        // We start at the lowest existing node containing any subscriptions or inclusions,
        // and work our way up to the root
        var level = nodes.count - 1
        while level >= 0 {
            let node = nodes[level]
            // The relative level describes how many levels the full path is below the current node
            // This number can directly be compared to the depth of subscriptions and inclusions
            // to check if they are relevant
            let relativePathLevel = path.count - level

            for (subscriptionId, subscription) in node.subscriptions {
                // Ignore previously handled subscribers
                guard !matchedSubscriptions.contains(subscriptionId) && !ignoredSubscriptions.contains(subscriptionId) else {
                    continue
                }
                // We check if the current node specifies a matching rule
                guard let isIncluded = subscription.isIncluded(depth: relativePathLevel) else {
                    continue
                }

                guard isIncluded else {
                    // Exclusion found
                    ignoredSubscriptions.insert(subscriptionId)
                    continue
                }
                // Inclusion found
                matchedSubscriptions.insert(subscriptionId)
            }
            // Advance to the next higher node
            level -= 1
        }

        // After reaching the root node, we have all applicable subscribers
        return matchedSubscriptions
    }

    /**
     Check if there is any rule registered for the subscription.
     - Parameter subscription: The id of the subscription to check
     - Returns: `true`, if one or more subscription rules exist for the id
     */
    func hasSubscriptionRules(for subscription: Int) -> Bool {
        if let rules = subscriptions[subscription], !rules.isEmpty {
            return true
        }
        for child in children.values {
            if child.hasSubscriptionRules(for: subscription) {
                return true
            }
        }
        return false
    }

     /**
     Indicate if the node does not contain a subscription or children
     - Note: This function does not check if child nodes are empty
     */
    var isEmpty: Bool {
        subscriptions.isEmpty && children.isEmpty
    }

    // MARK: Nodes and Paths

    /**
     Find an existing node, or create it in the tree.

     Used when inserting a subscription or exclusion.
     - Parameter path: The path to the node.
     - Returns: The final node corresponding to the path
     */
    func findOrCreateNode(at path: Path) -> SubscriptionTree {
        var node = self
        for component in path {
            if let child = node.children[component] {
                node = child
            } else {
                let child = SubscriptionTree()
                node.children[component] = child
                node = child
            }
        }
        return node
    }

    /**
     Get a node for a path below the current node, if it exists.

     This function is used for read and delete operations, and does not create any new nodes.
     - Parameter path: The path to select within the tree.
     - Returns: The node at the path, if it exists.
     */
    func existingNode(for path: Path) -> SubscriptionTree? {
        var current = self
        for name in path {
            guard let child = current.children[name] else {
                return nil
            }
            current = child
        }
        return current
    }

    /**
     Get all existing nodes in the tree on the way to a node corresponding to a path.
     - Note: Includes this node as the first element of the result
     - Parameter path: The path to the node.
     - Returns: All existing nodes along the path.
     */
    func existingNodes(for path: Path) -> [SubscriptionTree] {
        var result = [self]
        var last = self
        for component in path {
            guard let child = last.children[component] else {
                break
            }
            result.append(child)
            last = child
        }
        return result
    }

    private func getOrCreate(_ subscription: Int) -> NodeSubscriptions {
        if let existing = subscriptions[subscription] {
            return existing
        }
        let created = NodeSubscriptions()
        subscriptions[subscription] = created
        return created
    }

    // MARK: Rules

    /**
     Add an inclusion rule for a subscription.
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Parameter subscription: The id of the subscription
     */
    func include(depth: Int?, in subscription: Int) {
        getOrCreate(subscription).include(depth: depth)
    }

    /**
     Add an exclusion rule for a subscription.
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Parameter subscription: The id of the subscription
     */
    func exclude(depth: Int?, in subscription: Int) {
        getOrCreate(subscription).exclude(depth: depth)
    }

    /**
     Check if a subscription is triggered (included or excluded) by the rules at this node.
     - Parameter depth: The depth of the path below this node
     - Parameter subscription: The id of the subscription to check
     - Returns: `true`, if the path is included, `false`, if the path is excluded, `nil` if no rule applies
     */
    func includesSubpath(at depth: Int, in subscription: Int) -> Bool? {
        subscriptions[subscription]?.isIncluded(depth: depth)
    }

    /**
     Delete all information about a subscription, up to a given depth.

     Recurses into child nodes to remove all data.
     - Parameter subscription: The id of the subscription to target.
     - Parameter depth: The depth of the deletion
     */
    func deleteRules(for subscription: Int, depth: Int?) {
        subscriptions[subscription] = nil

        // Step recursing if depth is reached
        if let depth, depth == 0 {
            return
        }

        // Remove all child nodes that are empty after removing the subscriber from them
        let newDepth = depth?.subtracting(1)
        children = children.filter { _ , child in
            child.deleteRules(for: subscription, depth: newDepth)
            return !child.isEmpty
        }
    }

    /// The total number of nodes contained in this tree
    var numberOfNodes: Int {
        children.values.reduce(1) { $0 + $1.numberOfNodes }
    }

    /// The total number of rules for all nodes in this tree
    var numberOfRules: Int {
        let ownRules = subscriptions.values.reduce(0) { $0 + $1.ruleCount }
        return children.values.reduce(ownRules) { $0 + $1.numberOfRules }
    }
}

extension SubscriptionTree: CustomStringConvertible {

    var description: String {
        "Tree(\(numberOfNodes) nodes, \(numberOfRules) rules)"
    }
}

extension SubscriptionTree: DebugConvertible {

    func described(indent: String) -> [String] {
        var lines: [String] = []
        lines.append("subscriptions")
        if subscriptions.isEmpty {
            lines.append(indent + "None")
        } else {
            for (id, subscription) in subscriptions {
                lines.append(indent + "\(id)")
                lines.append(contentsOf: subscription.described(indent: indent).map { indent + indent + $0 })
            }
        }
        if !children.isEmpty {
            lines.append("children")
            for (name, child) in children.sorted(by: { $0.key < $1.key}) {
                lines.append(indent + name)
                lines.append(contentsOf: child.described(indent: indent).map { indent + indent + $0 })
            }
        }
        return lines
    }
}