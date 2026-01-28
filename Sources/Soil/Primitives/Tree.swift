

/**
 A path tree containing samples
 */
public final class Tree {

    /// The samples at this tree node
    public let samples: [Sample]

    /**
     The child nodes of the tree, indexed by their path component.
     */
    public let children: [PathComponent : Tree]

    /**
     Create a tree with samples and children.
     - Parameter samples: The data at the root node
     - Parameter children: The child nodes of the tree root.
     */
    public init(samples: [Sample] = [], children: [PathComponent : Tree] = [:]) {
        self.samples = samples
        self.children = children
    }
    /**
     Create a tree with a value at the root.
     - Parameter value: The value at the root.
     - Parameter timestamp: The optional timestamp associated with the value.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(value: Value, timestamp: Timestamp = .current(), children: [PathComponent : Tree] = [:]) {
        self.samples = [.init(value: value, timestamp: timestamp)]
        self.children = children
    }

    /**
     Create a tree with a sample at the root.
     - Parameter sample: The sample at the root.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(sample: Sample, children: [PathComponent : Tree] = [:]) {
        self.samples = [sample]
        self.children = children
    }

    /// Indicate if the tree contains any values, including in child nodes
    public var isEmpty: Bool {
        guard samples.isEmpty else {
            return false
        }
        for child in children.values {
            if !child.isEmpty { return false }
        }
        return true
    }

    /// An empty tree (no children, no samples)
    public static var empty: Tree {
        .init()
    }

    /// The most recent sample at the top node of this tree
    public var current: Sample? {
        samples.last
    }

    /// Count the number of nodes in this tree that contain samples
    public var numberOfNodesWithSamples: Int {
        // Count this node if it has samples, and sum up the trees of all children
        children.values.reduce(samples.isEmpty ? 0 : 1) { $0 + $1.numberOfNodesWithSamples }
    }
}