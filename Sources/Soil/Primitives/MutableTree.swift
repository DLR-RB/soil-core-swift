
/**
 An abstract tree that can be mutated.
 */
protocol MutableTree: Tree {

    /**
     The children of this tree node, indexed by their names
     */
    var children: [PathComponent : Self] { get set }
}

extension MutableTree {

    /**
     Find an existing node, or create it in the tree.

     Used when inserting a subscription or exclusion.
     - Parameter path: The path to the node.
     - Returns: The final node corresponding to the path
     */
    func findOrCreateNode(for path: Path) -> Self {
        var node = self
        for component in path {
            if let child = node.children[component] {
                node = child
            } else {
                let child = Self.init()
                node.children[component] = child
                node = child
            }
        }
        return node
    }
}
