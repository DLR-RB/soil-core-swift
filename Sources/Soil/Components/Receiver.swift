
/**
 A component that can receive values.
 - Note: In other contexts a receiver may also be called a sink, consumer, client, subscriber, or listener.
 */
public protocol Receiver {

    /**
     Receive a tree for a path.

     This is the singular function to inject data into a component.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     */
    func receive(_ tree: Tree, for path: Path)
}

extension Receiver {

    /**
     Save a value for a path.
     - Parameter value: The value to store.
     - Parameter path: The path of the value.
     - Parameter timestamp: The timestamp associated with the value
     */
    public func receive(_ value: Value, for path: Path, at timestamp: Timestamp = .current()) {
        let tree = Tree(samples: [.init(value: value, timestamp: timestamp)])
        receive(tree, for: path)
    }

    /**
     Save a timestamped value for a path
     - Parameter sample: The timestamped value to store.
     - Parameter path: The path of the value.
     */
    public func receive(_ sample: Sample, for path: Path) {
        receive(.init(samples: [sample]), for: path)
    }
}