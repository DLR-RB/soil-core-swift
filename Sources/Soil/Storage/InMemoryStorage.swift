

/**
 A simple storage implementation that keeps all values in memory.
 */
public final class InMemoryStorage {

    private var root: Node

    /**
     Create an in-memory storage.
     */
    public init() {
        root = Node()
    }

    private func existingNode(for path: Path) -> Node? {
        var node = root
        for component in path {
            guard let child = node.existingChild(named: component) else {
                return nil
            }
            node = child
        }
        return node
    }

    private func getOrCreateNode(for path: Path) -> Node {
        var node = root
        for component in path {
            node = node.child(named: component)
        }
        return node
    }
}

extension InMemoryStorage: Storage {

    /**
     Save a value for a path.
     - Parameter value: The value to store.
     - Parameter path: The path of the value.
     - Parameter timestamp: The timestamp associated with the value
     */
    public func save(_ value: Value, for path: Path, at timestamp: Timestamp? = nil) {
        let node = getOrCreateNode(for: path)
        let sample = Sample(value: value, timestamp: timestamp ?? .current())
        node.save(sample: sample)
    }

    /**
     Get the values of a path at a specific point in time, including sub-paths

     For each node, this function returns the most recent sample that is before or at the specified date.
     - Parameter path: The requested path
     - Parameter date: The point in time which is requested (`nil` indicates the current time).
     - Parameter depth: The number of levels in the sub-tree to include
     - Returns: The sample containing the current values of the requested sub-tree.
     */
    public func tree(for path: Path, beforeOrAt date: Timestamp? = nil, depth: Int? = nil) -> Tree {
        existingNode(for: path)?.tree(beforeOrAt: date, depth: depth) ?? Tree()
    }

    /**
     Provides the values in a given date range for a path, regardless of the value type.

     The start value is assumed to be later than the end value (backwards search).
     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted by most recent first. If a limit is set, then the `limit` newest values in the interval are returned.
     */
    public func samples(for path: Path, from start: Timestamp? = nil, to end: Timestamp? = nil, limit: Int? = nil) -> [Sample] {
        guard let node = existingNode(for: path) else {
            return []
        }
        if let start, let end, start < end {
            return node.samples(from: end, to: start, limit: limit)
        }
        return node.samples(from: start, to: end, limit: limit)
    }
}

private class Node {

    private var sample: Sample? = nil

    /// All historic values, sorted by oldest first
    private var history: [Sample] = []

    private var children: [PathComponent: Node] = [:]

    init() {

    }

    func child(named component: PathComponent) -> Node {
        if let child = existingChild(named: component) {
            return child
        }
        let child = Node()
        children[component] = child
        return child
    }

    func existingChild(named component: PathComponent) -> Node? {
        children[component]
    }

    func save(sample: Sample) {
        update(current: sample)
        insert(sample: sample)
    }

    private func update(current: Sample) {
        if let sample, sample.timestamp <= current.timestamp {
            return
        }
        sample = current
    }

    private func insert(sample: Sample) {
        // We assume that most new values will be recent, so check the last value first
        if history.last.isNilOrNotGreater(than: sample) {
            history.append(sample)
        } else {
            // Do a binary search in the sorted array and insert in the right place
            history.insertIntoSorted(sample)
        }
    }

    private func sample(beforeOrAt date: Timestamp?) -> Sample? {
        guard let date else {
            return sample
        }
        // Find the first index that where the date is larger, or endIndex
        // then substract 1 to get the last applicable index
        let index = history.partitioningIndex { $0.timestamp > date } - 1
        guard index >= history.startIndex else {
            return nil
        }
        return history[index]
    }

    func tree(beforeOrAt date: Timestamp?, depth: Int?) -> Tree {
        let sample = sample(beforeOrAt: date)

        // Only return the value, if depth is reached
        if let depth, depth == 0 {
            return Tree(sample: sample)
        }

        let newDepth = depth?.subtracting(1)
        let children: [PathComponent : Tree] = self.children.mapValues { child in
            child.tree(beforeOrAt: date, depth: newDepth)
        }
        return Tree(sample: sample, children: children)
    }

    /**
     Provides the samples in a given date range.

     The start value is assumed to be later than the end value (backwards search).
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The samples in the range, sorted by most recent first. If a limit is set, then the `limit` newest values in the interval are returned.
     */
    func samples(from start: Timestamp?, to end: Timestamp?, limit: Int?) -> [Sample] {
        let startIndex = findIndex(start: start)
        let endIndex = findIndex(end: end)
        // Move the start index if the range needs to be limited
        let limitedEndIndex = limit.map { max(endIndex, startIndex - $0) } ?? endIndex
        return Array(history[limitedEndIndex..<startIndex].reversed())
    }

    /// Return the history index after the last desired element
    private func findIndex(start: Timestamp?) -> Int {
        guard let start else {
            // All values requested until end of time,
            // so the subsequence will reach to the end of the array
            return history.endIndex
        }
        // Find the first index in the array where the sample date is not before the start date
        // This will be one past the end of the desired subsequence
        // If all values are smaller than the start date, then the end index is returned,
        // which is also one past the end of the subsequence
        return history.partitioningIndex { $0.timestamp >= start }
    }

    /// Return the history index of the first desired element
    private func findIndex(end: Timestamp?) -> Int {
        guard let end else {
            return history.startIndex
        }
        // Find the first index that should be included, i.e. where the date is larger/equal to `end`
        return history.partitioningIndex { $0.timestamp >= end }
    }
}