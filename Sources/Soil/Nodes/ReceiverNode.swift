
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
    func receive(_ tree: SampleTree) -> any Request
}


extension ReceiverNode {

    /**
     Save a value for a path.
     - Parameter value: The value to store.
     - Parameter timestamp: The timestamp associated with the value
     */
    @discardableResult
    public func receive(_ value: Value, at timestamp: Timestamp? = nil) -> any Request {
        return receive(Sample(value: value, timestamp: timestamp))
    }

    /**
     Save a timestamped value for a path
     - Parameter sample: The timestamped value to store.
     */
    @discardableResult
    public func receive(_ sample: Sample) -> any Request {
        receive([sample])
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
    func receive(_ samples: [Sample]) -> any Request {
        receive(SampleTree(samples: samples))
    }
}
