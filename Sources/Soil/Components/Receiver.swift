
/**
 A component that can receive values.

 The name `Receiver` was chosen to indicate that data from other components can be received, without necessarily being requested.

 Similar, but rejected terms include:
 - Sink: Vaguely implies that data is consumed, but it may also be retransmitted or stored.
 - Consumer: Implies that data is processed, but it may just be stored or forwarded
 - Client: Ambiguous, a client may have much functionality, including sending data
 - Subscriber: Implies that the component chooses which data to receive
 - Listener: Also suggests that the component is actively looking for data
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

    /**
     Save timestamped values for a path
     - Parameter samples: The timestamped values to store.
     - Parameter path: The path of the value.
     */
    public func receive(_ samples: [Sample], for path: Path) {
        receive(.init(samples: samples), for: path)
    }
}