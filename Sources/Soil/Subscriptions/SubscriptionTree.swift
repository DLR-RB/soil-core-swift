
/**
 A class to manage a single subscription.

 The data is organized in a tree of nodes, where each node stores information
 about inclusions and exclusions.

 It's possible for multiple inclusions and exclusions to be specified for the same path,
 e.g. `include(depth: 3)`, `exclude(depth: 2)`, `include(depth: 1)`.
 The rules are stored with the lowest depths first, since lower depths take precedence.
 */
final class SubscriptionTree {

    /// The nodes below this node, indexed by their name
    var children: [PathComponent : SubscriptionTree] = [:]

    /// The inclusion rules for the node, sorted by smallest first
    private var inclusions: [Int?] = []

    /// The exclusion rules for the node, sorted by smallest first
    private var exclusions: [Int?] = []

    /**
     Create a new subscription tree
     */
    init() { }

    /// Indicate if any rules are present
    var hasRules: Bool {
        !inclusions.isEmpty || !exclusions.isEmpty
    }

    /// The number of rules at this node
    var numberOfRules: Int {
        inclusions.count + exclusions.count
    }

    /// The total number of rules for all nodes in this tree
    var totalNumberOfRules: Int {
        return children.values.reduce(numberOfRules) { $0 + $1.numberOfRules }
    }

    /** Indicate if there is any rule registered for the subscription */
    var hasSubscriptionRulesInTree: Bool {
        if hasRules {
            return true
        }
        for child in children.values {
            if child.hasSubscriptionRulesInTree {
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
        !hasRules && children.isEmpty
    }

    /// The total number of nodes contained in this tree
    var numberOfNodes: Int {
        children.values.reduce(1) { $0 + $1.numberOfNodes }
    }

    // MARK: Root interface

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     */
    public func include(_ path: Path, depth: Int?) {
        findOrCreateNode(for: path).include(depth: depth)
    }

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     */
    public func exclude(_ path: Path, depth: Int?) {
        findOrCreateNode(for: path).exclude(depth: depth)
    }

    /**
     Delete subscription rules at a path with a given depth

     This function also deletes all empty nodes at the path after the rules are removed.
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     */
    public func deleteRules(at path: Path, depth: Int?) {
        let nodes = existingNodes(for: path)
        guard nodes.count == path.count + 1 else {
            // The node of the path does not exist,
            // so there are no rules to delete
            return
        }
        // Select the node of the exact path
        var node = nodes[path.count]

        // Delete the rules at the node
        node.deleteRules(depth: depth)

        // Traverse to the root and delete empty nodes
        var index = path.count - 1
        while node.isEmpty && index >= 0 {
            // Go the higher node
            node = nodes[index]

            // Get the path component of the child
            let component = path[index]

            // Delete the empty node
            node.children[component] = nil

            // Move up to the next node
            index -= 1
        }
    }

    /**
     Delete all rules in the tree
     */
    public func deleteAllRules() {
        deleteRules(at: [], depth: nil)
    }

    // MARK: Subscription modifications

    /**
     Add an inclusion with a depth.

     Adding an inclusion will remove an existing exclusion of the same depth.
     */
    func include(depth: Int?) {
        // We only insert an inclusion if it doesn't already exist
        guard !inclusions.contains(depth) else {
            return
        }
        // Remove a corresponding exclusion, if it exists
        if let index = exclusions.firstIndex(of: depth) {
            exclusions.remove(at: index)
        }
        inclusions.insertIntoSorted(depth, where: <)
    }

    /**
     Add an exclusion with a depth.

     Adding an exclusion will remove an existing inclusion of the same depth.
     */
    func exclude(depth: Int?) {
        // We only insert an exclusion if it doesn't already exist
        guard !exclusions.contains(depth) else {
            return
        }
        // Remove a corresponding inclusion, if it exists
        if let index = inclusions.firstIndex(of: depth) {
            inclusions.remove(at: index)
        }
        exclusions.insertIntoSorted(depth, where: <)
    }

    /**
     Delete all rules in this tree, up to a given depth.

     Recurses into child nodes to remove all data.
     - Parameter depth: The depth of the deletion
     */
    func deleteRules(depth: Int?) {
        inclusions = []
        exclusions = []

        // Step recursing if depth is reached
        if let depth, depth == 0 {
            return
        }

        // Remove all child nodes that are empty after removing the subscriber from them
        let newDepth = depth?.subtracting(1)
        children = children.filter { _ , child in
            child.deleteRules(depth: newDepth)
            return !child.isEmpty
        }
    }

    // MARK: Subscription queries

    /**
     Use the subscriptions to remove all excluded parts of a tree.
     - Parameter tree: The original tree to strip
     - Parameter path: The path of the tree in relation to the subscription tree
     - Returns: The reduced tree, if any inclusion rules match.
     */
    func reduce(_ tree: any SampleTree, for path: Path) -> (any SampleTree)? {
        let nodes = allNodes(for: path)
        // Note: The path nodes always include at least the root node
        return nodes.last!.reduce(tree, parents: nodes)
    }

    /**
     Get all nodes along a path, including dummy nodes if needed

     - Parameter path: The path for which to collect the nodes
     - Note: A single dummy node is added multiple times if needed,
       so the nodes must not be modified while used.
     */
    private func allNodes(for path: Path) -> [SubscriptionTree] {
        let nodes = existingNodes(for: path)
        let missingCount = path.count - nodes.count
        if missingCount == 0 {
            return nodes
        }
        return nodes + .init(repeating: .init(), count: missingCount)
    }

    /**
     Use the subscriptions to remove all excluded parts of a tree.
     - Parameter tree: The original tree to strip
     - Parameter parents: The nodes above this node in the subscription tree.
     - Returns: The reduced tree, if any samples or children remain after reduction.

     The samples of the tree root are included in the result,
     if either the current node as a suitable rule, or if a parent node matches.
     The children are included if their subscriptions match, which also consider the rules of this node.
     */
    func reduce(_ tree: any SampleTree, parents: [SubscriptionTree] = []) -> (any SampleTree)? {
        let childrenAreSubscribed = isSubscribed(parentNodes: parents, depth: 1)
        let childParents =  parents + [self]
        let reduced: [String : any SampleTree] = tree.children.reduce(into: [:]) { (dict, child) in
            guard let subscriptionRuleChild = children[child.key] else {
                // No rules for child, so use only the ones of the current node
                if childrenAreSubscribed {
                    dict[child.key] = child.value
                }
                return
            }
            dict[child.key] = subscriptionRuleChild.reduce(child.value, parents: childParents)
        }

        let samples = isSubscribed(parentNodes: parents, depth: 0) ? tree.samples : []
        if samples.isEmpty && reduced.isEmpty {
            return nil
        }

        return ImmutableSampleTree(
            samples: samples,
            children: reduced
        )
    }

    /**
     Check if the current node or parent nodes have a matching subscription for a given depth below this node.
     - Parameter parentNodes: The nodes above this node in the subscription tree.
     - Parameter depth: The depth below this node to check
     - Returns: `true`, if the depth is included in the subscription

     If no applicable rule exists for the current node, then the parent node is checked.
     This process repeats until the tree root is reached.
     */
    private func isSubscribed(parentNodes: [SubscriptionTree], depth: Int) -> Bool {
        if let isIncluded = isIncluded(depth: depth) {
            return isIncluded
        }
        guard let parent = parentNodes.last else {
            // No parent nodes, so not included
            return false
        }
        return parent.isSubscribed(parentNodes: parentNodes.dropLast(), depth: depth + 1)
    }

    /**
     Check if a path is covered by the inclusions in the tree.

     The function first finds all existing nodes along the path,
     and then traverses them from the bottom node to the root.
     If a node in the subscription tree has a matching rule
     (based on the relative depth), then the inclusion or exclusion is returned.
     If the full path is traversed to the top, then the path is not included.

     - Parameter path: The path to query subscriptions for
     - Returns: `true`, if the path is included by the subscription.
     */
    func isSubscribed(to path: Path) -> Bool {
        // Traverse the tree to get the nodes along the path,
        // so that we can move towards the root
        let nodes = existingNodes(for: path)

        // We start at the lowest existing node containing any subscriptions or inclusions,
        // and work our way up to the root
        var level = nodes.count - 1
        while level >= 0 {
            let node = nodes[level]
            // The relative level describes how many levels the full path is below the current node
            // This number can directly be compared to the depth of subscriptions and inclusions
            // to check if they are relevant
            let relativePathLevel = path.count - level

            // We check if the current node specifies a matching rule
            if let isIncluded = node.isIncluded(depth: relativePathLevel) {
                return isIncluded
            }
            // Advance to the next higher node
            level -= 1
        }

        // If we reach past the root node then the path is not contained in the subscription
        return false
    }

    /**
     Check if the subscription of a path is triggered (included or excluded) by the rules at this node.
     - Parameter depth: The depth of the path below this node
     - Returns: `true`, if the path is included, `false`, if the path is excluded, `nil` if no rule applies
     */
    private func isIncluded(depth: Int) -> Bool? {
        // Find the smallest depth that includes the given depth
        // Smaller depths take precedence, so we can ignore the rest, as well as all rules that don't apply
        guard let inclusionDepth = inclusions.first(where: { $0.largerEqual(depth) }) else {
            // No inclusion, check if excluded
            // It's excluded if any exclusion rule is applicable (rule depth bigger or equal to path depth)
            if exclusions.contains(where: { $0.largerEqual(depth) }) {
                return false
            }
            // Neither included nor excluded
            return nil
        }
        guard let exclusionDepth = exclusions.first(where: { $0.largerEqual(depth) }) else {
            // No exclusion, so it's included
            return true
        }
        // Both inclusion and exclusion depth
        // The lower value wins
        // equality is prevented during insertion of rules
        return inclusionDepth < exclusionDepth
    }
}

extension SubscriptionTree: MutableTree {

}

extension SubscriptionTree: CustomStringConvertible {

    var description: String {
        "Tree(\(numberOfNodes) nodes, \(totalNumberOfRules) rules)"
    }
}

extension SubscriptionTree: DebugConvertible {

    func described(indent: String) -> [String] {
        var lines: [String] = []
        if hasRules {
            lines.append("rules")
            for depth in inclusions {
                lines.append("- include(\(depth?.description ?? "nil"))")
            }
            for depth in exclusions {
                lines.append("- exclude(\(depth?.description ?? "nil"))")
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