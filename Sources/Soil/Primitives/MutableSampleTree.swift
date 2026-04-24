
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
    var tree: any SampleTree {
        ImmutableSampleTree(samples: samples, children: children.mapValues { $0.tree })
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

    /**
     Insert a tree into this tree.
     - Parameter tree: The tree to add
     - Parameter path: The path within this tree where the tree is added.
     - Note: The samples are appended to existing samples without sorting.
     */
    func merge(_ tree: any SampleTree, at path: Path) {
        findOrCreateNode(for: path).merge(tree)
    }

    /**
     Insert a tree into this tree.
     - Parameter tree: The tree to add
     - Note: The samples are appended to existing samples without sorting.
     */
    func merge(_ tree: any SampleTree) {
        samples.append(contentsOf: tree.samples)
        let children = tree.children
        for (name, child) in children {
            let node = getOrCreate(child: name)
            node.merge(child)
        }
    }

    /**
     Compute the path of the first node in the tree that has samples or more than one child,
     and return this path and the sub-tree at this node.
     */
    func containedTree() -> (path: Path, tree: MutableSampleTree) {
        var path = Path()
        var current = self
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
