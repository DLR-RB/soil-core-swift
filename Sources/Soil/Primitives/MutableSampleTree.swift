
/**
 A tree structure that allows mutations to the samples and nodes
 */
final class MutableSampleTree: MutableTree {

    /// The samples at this tree node
    var samples: [Sample]

    /// The child nodes of the tree, indexed by their path component.
    var children: [PathComponent : MutableSampleTree]

    /**
     Create a tree with samples and children.
     - Parameter samples: The data at the root node
     - Parameter children: The child nodes of the tree root.
     */
    init(samples: [Sample] = [], children: [PathComponent : MutableSampleTree] = [:]) {
        self.samples = samples
        self.children = children
    }

    /// Create an empty tree node.
    init() {
        self.samples = []
        self.children = [:]
    }

    /// Convert to an immutable tree
    var tree: SampleTree {
        .init(samples: samples, children: children.mapValues { $0.tree })
    }

    /**
     Insert samples into the tree.
     - Parameter samples: The samples to add
     - Parameter path: The path within this tree where the samples are added.
     - Note: The samples are appended to existing samples without sorting.
     */
    func insert(_ samples: [Sample], at path: Path) {
        findOrCreateNode(for: path).samples.append(contentsOf: samples)
    }
}
