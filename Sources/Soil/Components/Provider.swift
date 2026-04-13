
/**
 A component that can provide values.

 The term `provider` was chosen to emphasize the fact that this type of component does not
 send values by itself, but makes data available when requested.

 - Note: In other contexts, a provider may also be called a data source, sender, producer, publisher, transmitter, or writer.
 */
public protocol Provider: Sendable {

    /**
     Read a data tree for a given path within a given interval.

     This is the singular function to serve all data retrieval needs.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     The `limitPerNode` is applied in sort order.

     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels below the path to include in the result
     - Parameter limitPerNode: The maximum number of values to return for each node of the tree (defaults to `nil`, e.g. no limit)
     - Returns: The tree with the given depth, limited to the maximum count per node, for the requested interval.
     - Note: This function is `async`, because providing the data may take some time.
       It could be retrieved over a network, from an otherwise slow database, or from other components.
     */
    func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) async -> any SampleTree
}

extension Provider {

    /**
     Get the values of a path at a specific point in time, including sub-paths

     For each node, this function returns the most recent sample that is before or at the specified date.
     - Parameter path: The requested path
     - Parameter date: The point in time which is requested (inclusive, `nil` indicates the current time).
     - Parameter depth: The number of levels in the sub-tree to include
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    public func tree(for path: Path = [], beforeOrAt time: Timestamp, depth: Int? = nil) async -> any SampleTree {
        await tree(for: path, from: nil, to: time, depth: depth, limitPerNode: 1)
    }

    /**
     Provides the values in a given date range for a path, regardless of the value type.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     The `limit` is applied in sort order.

     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, limit to the maximum count
     */
    public func samples(for path: Path = [], from start: Timestamp? = nil, to end: Timestamp? = nil, limit: Int? = nil) async -> [Sample] {
        await tree(for: path, from: start, to: end, depth: 0, limitPerNode: limit).samples
    }

    /**
     Get the value for a path at a specific point in time.
     - Parameter path: The requested path
     - Parameter date: The point in time for which the value is requested (inclusive, `nil` indicates the most recent sample)
     - Returns: If present: The most recent value for the path where the timestamp is before the provided date.
     */
    public func sample(for path: Path = [], beforeOrAt date: Timestamp) async -> Sample? {
        await tree(for: path, from: nil, to: date, depth: 0, limitPerNode: 1).samples.first
    }

    /**
     Get the current value for a path.
     - Parameter path: The requested path
     - Returns: The most recent timestamped value for the path, if present
     */
    public func currentValue(for path: Path = []) async -> Value? {
        await currentSample(for: path)?.value
    }

    /**
     Get the current value for a path.
     - Parameter path: The requested path
     - Returns: The most recent timestamped value for the path, if present
     */
    public func currentSample(for path: Path = []) async -> Sample? {
        await sample(for: path, beforeOrAt: .current())
    }

    /**
     Get the current values of a path, including sub-paths up to a given depth
     - Parameter path: The requested path
     - Parameter depth: The number of levels in the sub-tree to include
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    public func currentTree(for path: Path = [], depth: Int?) async -> any SampleTree {
        await tree(for: path, from: nil, to: .current(), depth: depth, limitPerNode: 1)
    }

    /**
     Get the current values of a path, including all sub-paths
     - Parameter path: The requested path
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    public func currentTree(for path: Path = []) async -> any SampleTree {
        await currentTree(for: path, depth: nil)
    }
}
