
/**
 A path tree containing samples
 */
public protocol SampleTree: CustomStringConvertible, Sendable {

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
     Create a tree with a value at the root, after converting it to a SOIL value.
     - Parameter value: The value at the root.
     - Parameter timestamp: The optional timestamp associated with the value.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     - Throws: An error, if the value can't be converted to a SOIL value
     */
    // Disfavored, so that literals use the non-throwing `Value` overload
    @_disfavoredOverload
    public init(value: some ValueConvertible, timestamp: Timestamp? = nil, children: [PathComponent : any SampleTree] = [:]) throws {
        self.init(samples: [try .init(value: value, timestamp: timestamp)], children: children)
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

    /**
     The sample at this node with the closest timestamp before the current time.

     If samples exist without a timestamp set, then the first one is returned
     */
    public var currentSample: Sample? {
        let now = Timestamp.current()
        var result: Sample? = nil
        for sample in samples {
            guard let timestamp = sample.timestamp else {
                // If a sample has no timestamp, then it is treated as the current time
                return sample
            }
            if timestamp > now {
                // Samples in the future are skipped
                continue
            }
            if let previous = result?.timestamp, previous > timestamp {
                // No value selected previously, or already closer to now
                continue
            }
            // Closer match found
            result = sample
        }
        return result
    }

    /**
     The value of the sample at this node with the closest timestamp before the current time.

     If samples exist without a timestamp set, then the value of the first match is returned
     */
    public var currentValue: Value? {
        currentSample?.value
    }

    /**
     The current value at this node, converted to a specific type.

     The value is selected as for ``currentValue``.
     - Parameter type: The type to convert the value to
     - Returns: The converted value, or `nil`, if no value exists or it can't be converted
     */
    public func currentValue<T: ValueConvertible>(as type: T.Type = T.self) -> T? {
        currentSample?.value(as: type)
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

    /**
     Compute the path of the first node in the tree that has samples or more than one child,
     and return this path and the sub-tree at this node.
     */
    func containedTree() -> (path: Path, tree: any SampleTree) {
        var path = Path()
        var current: any SampleTree = self
        // If there are samples, then we need to directly return the tree
        // If there is more than one child, or no children, the return the entire tree, which may contain samples
        while (current.samples.isEmpty && current.children.count == 1) {
            let (name, child) = current.children.first!
            current = child
            path.append(name)
        }
        return (path, current)
    }
}

extension SampleTree {

    public var description: String {
        describe().joined(separator: "\n")
    }

    public func describe(indentLevel: Int = 0, indent: String = "  ") -> [String] {
        let baseIndent = String(repeating: indent, count: indentLevel)
        var result: [String] = []
        let samples = samples
        if !samples.isEmpty {
            let sampleIndent = baseIndent + indent
            result.append(baseIndent + "samples:")
            for sample in samples {
                result.append(sampleIndent + sample.description)
            }
        }
        let children = children
        if !children.isEmpty {
            let childIndent = baseIndent + indent
            result.append(baseIndent + "children:")
            for (name, child) in children {
                result.append(childIndent + name + ":")
                result.append(contentsOf: child.describe(indentLevel: indentLevel + 2, indent: indent))
            }
        }

        return result
    }
}