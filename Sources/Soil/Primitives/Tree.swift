

/**
 An abstract tree using path components
 */
protocol Tree {

    /// Create a tree node
    init()

    /// The children of this tree node, indexed by their names
    var children: [PathComponent : Self] { get }
}

extension Tree {

    /**
     Get a node for a path below the current node, if it exists.

     This function is used for read and delete operations, and does not create any new nodes.
     - Parameter path: The path to select within the tree.
     - Returns: The node at the path, if it exists.
     */
    func existingNode(for path: Path) -> Self? {
        var current = self
        for name in path {
            guard let child = current.children[name] else {
                return nil
            }
            current = child
        }
        return current
    }

    /**
     Get all existing nodes in the tree on the way to a node corresponding to a path.
     - Note: Includes this node as the first element of the result
     - Parameter path: The path to the node.
     - Returns: All existing nodes along the path.
     */
    func existingNodes(for path: Path) -> [Self] {
        var result = [self]
        var last = self
        for component in path {
            guard let child = last.children[component] else {
                break
            }
            result.append(child)
            last = child
        }
        return result
    }
}