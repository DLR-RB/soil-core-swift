

/**
 A path tree containing samples
 */
public final class Tree {

    /// The value at the root of this tree
    public let value: Value?

    /**
     The timestamp associated with `value`, if it is set.
     */
    public let timestamp: Timestamp?

    /**
     The child nodes of the tree, indexed by their path component.
     */
    public let children: [PathComponent : Tree]

    /**
     Create a tree with a value at the root.
     - Parameter value: The value at the root.
     - Parameter timestamp: The optional timestamp associated with the value.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(value: Value, timestamp: Timestamp? = nil, children: [PathComponent : Tree] = [:]) {
        self.value = value
        self.timestamp = timestamp
        self.children = children
    }

    /**
     Create a tree with a sample at the root.
     - Parameter sample: The sample at the root.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(sample: Sample?, children: [PathComponent : Tree] = [:]) {
        self.value = sample?.value
        self.timestamp = sample?.timestamp
        self.children = children
    }

    /**
     Create a tree without a value at the root.
     - Parameter children: The child nodes of the tree, indexed by their path component.
     */
    public init(children: [PathComponent : Tree] = [:]) {
        self.value = nil
        self.timestamp = nil
        self.children = children
    }

    /// Indicate if the tree contains any values, including in child nodes
    public var isEmpty: Bool {
        if value != nil { return false }
        for child in children.values {
            if !child.isEmpty { return false }
        }
        return true
    }
}
