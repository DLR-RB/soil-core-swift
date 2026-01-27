
/**
 An internal class to store all inclusion and exclusion rules for a single subscription at a single node.

 It's possible for multiple inclusions and exclusions to be specified for the same path,
 e.g. `include(depth: 3)`, `exclude(depth: 2)`, `include(depth: 1)`.
 The rules are stored with the lowest depths first, since lower depths take precedence.
 */
final class NodeSubscriptions {

    init() { }

    /// The inclusion rules for the node, sorted by smallest first
    private var inclusions: [Int?] = []

    /// The exclusion rules for the node, sorted by smallest first
    private var exclusions: [Int?] = []

    /// Indicate if any rules are present
    var isEmpty: Bool {
        inclusions.isEmpty && exclusions.isEmpty
    }

    /// The number of rules contained in this node
    var ruleCount: Int {
        inclusions.count + exclusions.count
    }

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
     Check if the subscription of a path is triggered (included or excluded) by the rules at this node.
     - Parameter depth: The depth of the path below this node
     - Returns: `true`, if the path is included, `false`, if the path is excluded, `nil` if no rule applies
     */
    func isIncluded(depth: Int) -> Bool? {
        // Find the smallest depth that includes the given depth
        // Smaller depths take precedence, so we can ignore the rest, as well as all rules that don't apply
        guard let inclusionDepth = inclusions.first(where: { $0 >= depth }) else {
            // No inclusion, check if excluded
            // It's excluded if any exclusion rule is applicable (rule depth bigger or equal to path depth)
            return !exclusions.contains { $0 >= depth }
        }
        guard let exclusionDepth = exclusions.first(where: { $0 >= depth }) else {
            // No exclusion, so it's included
            return true
        }
        // Both inclusion and exclusion depth
        // The lower value wins
        // equality is prevented during insertion of rules
        return inclusionDepth < exclusionDepth
    }
}

extension NodeSubscriptions: CustomStringConvertible {

    var description: String {
        "\(inclusions.count) inclusions, \(exclusions.count) exclusions"
    }
}

extension NodeSubscriptions: DebugConvertible {

    func described(indent: String) -> [String] {
        if isEmpty {
            return ["empty"]
        }
        var lines: [String] = []
        for depth in inclusions {
            lines.append("include(\(depth?.description ?? "nil"))")
        }
        for depth in exclusions {
            lines.append("exclude(\(depth?.description ?? "nil"))")
        }
        return lines
    }
}