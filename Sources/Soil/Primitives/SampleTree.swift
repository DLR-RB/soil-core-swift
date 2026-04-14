
/**
 A path tree containing samples
 */
public protocol SampleTree: Sendable {

    /// The samples at this tree node
    var samples: [Sample] { get }

    /// The child nodes of the tree, indexed by their path component.
    var children: [PathComponent : any SampleTree] { get }

    /**
     Create a tree with samples and children.
     - Parameter samples: The data at the root node
     - Parameter children: The child nodes of the tree root.
     */
    init(samples: [Sample], children: [PathComponent : any SampleTree])
}

extension SampleTree {

    /// Create an empty tree.
    public init() {
        self.init(samples: [], children: [:])
    }

    /**
     Create a tree with a value at the root.
     - Parameter value: The value at the root.
     - Parameter timestamp: The optional timestamp associated with the value.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(value: Value, timestamp: Timestamp? = nil, children: [PathComponent : any SampleTree] = [:]) {
        self.init(samples: [.init(value: value, timestamp: timestamp)], children: children)
    }

    /**
     Create a tree with a sample at the root.
     - Parameter sample: The sample at the root.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(sample: Sample, children: [PathComponent : any SampleTree] = [:]) {
        self.init(samples: [sample], children: children)
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
    public static var empty: Self {
        Self.init()
    }

    /**
     The most recent sample at the top node of this tree
     - Note: If the samples contain future values, then those will be returned as well
     */
    public var newestSample: Sample? {
        samples.max()
    }

    /// Count the number of nodes in this tree that contain samples
    public var numberOfNodesWithSamples: Int {
        // Count this node if it has samples, and sum up the trees of all children
        children.values.reduce(samples.isEmpty ? 0 : 1) { $0 + $1.numberOfNodesWithSamples }
    }

    /// The total number of samples present in this tree
    public var totalNumberOfSamples: Int {
        children.values.reduce(samples.count) { $0 + $1.totalNumberOfSamples }
    }

    public func isEqual(to other: any SampleTree) -> Bool {
        guard samples == other.samples else {
            return false
        }
        let one = children
        let two = other.children
        guard one.count == two.count else {
            return false
        }
        for (name, child) in one {
            guard let child2 = two[name] else {
                return false
            }
            guard child.isEqual(to: child2) else {
                return false
            }
        }
        return true
    }
}
