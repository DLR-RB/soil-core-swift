import Foundation

/**
 The interface to a storage type providing presistence for values with a path tree structure.
 */
public protocol Storage {

    /**
     Save a value for a path.
     - Parameter value: The value to store.
     - Parameter path: The path of the value.
     - Parameter timestamp: The timestamp associated with the value
     */
    func save(_ value: Value, for path: Path, at timestamp: Date?)

    /**
     Get the values of a path at a specific point in time, including sub-paths

     For each node, this function returns the most recent sample that is before or at the specified date.
     - Parameter path: The requested path
     - Parameter date: The point in time which is requested (`nil` indicates the current time).
     - Parameter depth: The number of levels in the sub-tree to include
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    func tree(for path: Path, beforeOrAt date: Date?, depth: Int?) -> Tree

    /**
     Provides the values in a given date range for a path, regardless of the value type.

     The start value is assumed to be later than the end value (backwards search).
     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted by most recent first. If a limit is set, then the `limit` newest values in the interval are returned.
     */
    func samples(for path: Path, from start: Date?, to end: Date?, limit: Int?) -> [Sample]

}

extension Storage {

    /**
     Save a value for a path with the current time
     - Parameter value: The value to store.
     - Parameter path: The path of the value.
     */
    public func save(_ value: Value, for path: Path) {
        save(value, for: path, at: nil)
    }

    /**
     Save a timestamped value for a path
     - Parameter sample: The timestamped value to store.
     - Parameter path: The path of the value.
     */
    public func save(_ sample: Sample, for path: Path) {
        save(sample.value, for: path, at: sample.timestamp)
    }

    /**
     Get the value for a path at a specific point in time.
     - Parameter path: The requested path
     - Parameter date: The point in time for which the value is requested (`nil` indicates the most recent sample)
     - Returns: If present: The most recent value for the path where the timestamp is before the provided date.
     */
    public func sample(for path: Path, beforeOrAt date: Date?) -> Sample? {
        let sample = tree(for: path, beforeOrAt: date, depth: 0)
        guard let value = sample.value else {
            return nil
        }
        return .init(value: value, timestamp: sample.timestamp ?? Date())
    }

    /**
     Get the current value for a path.
     - Parameter path: The requested path
     - Returns: The most recent timestamped value for the path, if present
     */
    public func sample(for path: Path) -> Sample? {
        sample(for: path, beforeOrAt: nil)
    }

    /**
     Get the current values of a path, including sub-paths up to a given depth
     - Parameter path: The requested path
     - Parameter depth: The number of levels in the sub-tree to include
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    public func tree(for path: Path, depth: Int?) -> Tree {
        tree(for: path, beforeOrAt: nil, depth: depth)
    }

    /**
     Get the current values of a path, including all sub-paths
     - Parameter path: The requested path
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    public func tree(for path: Path) -> Tree {
        tree(for: path, depth: nil)
    }
}
