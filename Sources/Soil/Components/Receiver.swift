
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
public protocol Receiver: Sendable {

    /**
     Receive a request to ingest a tree for a path.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.

     - Parameter tree: The tree to ingest.
     - Parameter path: The path of the root node of the provided tree
     - Returns: A request handle, to optionally wait until the data is ingested.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    func accept(_ tree: any SampleTree, for path: Path) -> any Request
}

extension Receiver {

    /**
     Receive a tree for the root path.
     - Parameter tree: The tree to store.
     - Returns: A request to wait for completion.
     */
    @discardableResult
    public func accept(_ tree: any SampleTree) -> any Request {
        accept(tree, for: [])
    }

    /**
     Save a value for a path.
     - Parameter value: The value to store.
     - Parameter path: The path of the value.
     - Parameter timestamp: The timestamp associated with the value
     */
    @discardableResult
    public func accept(_ value: Value, for path: Path = [], at timestamp: Timestamp? = nil) -> any Request {
        return accept(Sample(value: value, timestamp: timestamp), for: path)
    }

    /**
     Save a value for a path, after converting it to a SOIL value.
     - Parameter value: The value to store.
     - Parameter path: The path of the value.
     - Parameter timestamp: The timestamp associated with the value
     - Throws: An error, if the value can't be converted to a SOIL value
     */
    @discardableResult
    // Disfavored, so that literals use the non-throwing `Value` overload
    @_disfavoredOverload
    public func accept(_ value: some ValueConvertible, for path: Path = [], at timestamp: Timestamp? = nil) throws -> any Request {
        accept(try value.soilValue, for: path, at: timestamp)
    }

    /**
     Save a timestamped value for a path
     - Parameter sample: The timestamped value to store.
     - Parameter path: The path of the value.
     */
    @discardableResult
    public func accept(_ sample: Sample, for path: Path = []) -> any Request {
        accept([sample], for: path)
    }

    /**
     Receive samples for a path.

     Components may choose to ignore samples due to access rights or other reasons.
     - Parameter samples: The samples to store for the path.
     - Parameter path: The path associated with the samples
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    public func accept(_ samples: [Sample], for path: Path = []) -> any Request {
        let tree = ImmutableSampleTree(samples: samples)
        return accept(tree, for: path)
    }
}
