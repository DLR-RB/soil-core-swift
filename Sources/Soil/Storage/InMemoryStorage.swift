

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
     - Returns: The values in the range, sorted from `start` to `end`, or by oldest first, if either is `nil`. If a limit is set, then the `limit` values counted from `start` (or oldest) are returned.
     */
    public func samples(for path: Path, from start: Timestamp? = nil, to end: Timestamp? = nil, limit: Int? = nil) -> [Sample] {
        existingNode(for: path)?.samples(from: start, to: end, limit: limit) ?? []
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
        updateCurrentSampleInTreeIfNeeded(sample)
        insertSampleIntoHistory(sample)
    }

    private func updateCurrentSampleInTreeIfNeeded(_ current: Sample) {
        if let sample, sample.timestamp > current.timestamp {
            return
        }
        sample = current
    }

    private func insertSampleIntoHistory(_ sample: Sample) {
        // We assume that most new values will be recent, so check the last value first
        if let last = history.last, last.timestamp <= sample.timestamp {
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
     Provides the values in a given date range for a path, regardless of the value type.

     The start value is assumed to be later than the end value (backwards search).
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted from `start` to `end`, or by oldest first, if either is `nil`. If a limit is set, then the `limit` values counted from `start` (or oldest) are returned.
     */
    func samples(from start: Timestamp?, to end: Timestamp?, limit: Int?) -> [Sample] {
        guard let start else {
            // No start provided, so use beginning of time, and sort ascending
            guard let end else {
                guard let limit else {
                    // No start, end, or limit, so return the full history
                    return history
                }
                // Limit the full history, return in ascending order (already sorted correctly)
                return Array(history.prefix(limit))
            }
            // No start, but end provided, return in ascending order
            return selectAscending(start: 0, end: findIndex(end: end), limit: limit)
        }

        guard let end else {
            // Start, but no end, so return in ascending order
            let startIndex = findIndex(start: start)
            return selectAscending(start: startIndex, end: history.endIndex, limit: limit)
        }
        guard start < end else {
            // Reverse order requested
            // This case needs to be treated differently, due to start being exclusive and end inclusive
            return selectDescending(start: start, end: end, limit: limit)
        }
        // Both start and end given in "correct" order, so return ascending
        let startIndex = findIndex(start: start)
        let endIndex = findIndex(end: end)
        return selectAscending(start: startIndex, end: endIndex, limit: limit)
    }

    private func selectAscending(start startIndex: Int, end endIndex: Int, limit: Int?) -> [Sample] {
        // Move the end index if the range needs to be limited
        let limitedEndIndex = limit.map { min(endIndex, startIndex + $0) } ?? endIndex
        return Array(history[startIndex..<limitedEndIndex])
    }

    private func selectDescending(start: Timestamp, end: Timestamp, limit: Int?) -> [Sample] {
        // The starting index of the subsequence is given by `end`, since end < start
        // End is inclusive, so we find the first index larger than or equal to `end`
        let startIndex = history.partitioningIndex { $0.timestamp >= end }

        // The end index is given by `start`, but exclusive.
        // Since we need the index after the last included element, we select the first index larger than or equal to `start`
        let endIndex = history.partitioningIndex { $0.timestamp >= start }
        // Move the end index if the range needs to be limited
        let limitedEndIndex = limit.map { min(endIndex, startIndex + $0) } ?? endIndex
        // Reverse the subsequence, because the order is expected to be descending (start > end)
        return Array(history[startIndex..<limitedEndIndex].reversed())
    }

    /// Return the history index of the first desired element for searches in ascending order
    private func findIndex(start: Timestamp) -> Int {
        // Find the first index in the array where the sample date is after the start date (start is exclusive)
        // If all values are smaller than or equal to the start date, then the end index is returned
        return history.partitioningIndex { $0.timestamp > start }
    }

    /// Return the history index past the last desired element for searches in ascending order
    private func findIndex(end: Timestamp) -> Int {
        // End is inclusive, so we find the first index that is greater than end
        // If all elements are smaller equal end, then the end index is returned
        return history.partitioningIndex { $0.timestamp > end }
    }
}