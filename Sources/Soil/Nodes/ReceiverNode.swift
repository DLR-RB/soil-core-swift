
public protocol ReceiverNode: Sendable {

    /**
     Receive a request to store a tree.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.

     - Parameter tree: The tree to store.
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    func accept(_ tree: any SampleTree) -> any Request
}


extension ReceiverNode {

    /**
     Save a value for a path.
     - Parameter value: The value to store.
     - Parameter timestamp: The timestamp associated with the value
     */
    @discardableResult
    public func accept(_ value: Value, at timestamp: Timestamp? = nil) -> any Request {
        return accept(Sample(value: value, timestamp: timestamp))
    }

    /**
     Save a value, after converting it to a SOIL value.
     - Parameter value: The value to store.
     - Parameter timestamp: The timestamp associated with the value
     - Throws: An error, if the value can't be converted to a SOIL value
     */
    @discardableResult
    // Disfavored, so that literals use the non-throwing `Value` overload
    @_disfavoredOverload
    public func accept(_ value: some ValueConvertible, at timestamp: Timestamp? = nil) throws -> any Request {
        accept(try value.soilValue, at: timestamp)
    }

    /**
     Save a value as a tree, after converting it to a SOIL tree.
     - Parameter value: The value to store.
     - Parameter timestamp: The timestamp set for all samples of the tree that don't have one
     - Throws: An error, if the value can't be converted to a SOIL tree
     */
    @discardableResult
    public func accept(tree value: some SampleTreeConvertible, at timestamp: Timestamp? = nil) throws -> any Request {
        let tree = try value.sampleTree
        return accept(timestamp.map { tree.withTimestamp($0) } ?? tree)
    }

    /**
     Save a timestamped value for a path
     - Parameter sample: The timestamped value to store.
     */
    @discardableResult
    public func accept(_ sample: Sample) -> any Request {
        accept([sample])
    }

    /**
     Receive samples.

     Components may choose to ignore samples due to access rights or other reasons.
     - Parameter samples: The samples to store for the path.
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    @discardableResult
    func accept(_ samples: [Sample]) -> any Request {
        accept(ImmutableSampleTree(samples: samples))
    }
}
