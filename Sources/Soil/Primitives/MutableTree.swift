
/**
 An abstract tree that can be mutated.
 */
protocol MutableTree: Tree, AnyObject {

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
            node = node.getOrCreate(child: component)
        }
        return node
    }

    func createChild(named name: PathComponent) -> Self {
        let child = Self.init()
        children[name] = child
        return child
    }

    func add(child: Self, named name: PathComponent) {
        children[name] = child
    }

    func getOrCreate(child name: PathComponent) -> Self {
        if let child = children[name] {
            return child
        }
        return createChild(named: name)
    }
}
