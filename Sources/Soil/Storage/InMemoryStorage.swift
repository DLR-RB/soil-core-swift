

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
    public func receive(_ tree: Tree, for path: Path) {
        let node = getOrCreateNode(for: path)
        node.save(tree)
    }

    /**
     Get the values of a path at a specific point in time, including sub-paths

     For each node, this function returns the most recent sample that is before or at the specified date.
     - Parameter path: The requested path
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter depth: The number of levels in the sub-tree to include
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted from `start` to `end`, or by oldest first, if either is `nil`. If a limit is set, then the `limit` values counted from `start` (or oldest) are returned.
     */
    public func tree(
        for path: Path,
        from start: Timestamp? = nil,
        to end: Timestamp? = nil,
        depth: Int? = nil,
        limitPerNode: Int? = nil
    ) -> Tree {
        existingNode(for: path)?.tree(from: start, to: end, depth: depth, limitPerNode: limitPerNode) ?? .empty
    }

    public func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        existingNode(for: path)?.delete(from: start, to: end, depth: depth)
    }
}

private class Node {

    /// All historic values, sorted by oldest first
    private var history: [Sample] = []

    private var children: [PathComponent: Node] = [:]

    init() { }

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

    func save(_ tree: Tree) {
        for sample in tree.samples {
            insertSampleIntoHistory(sample)
        }
    }

    private func insertSampleIntoHistory(_ sample: Sample
) {
        // We assume that most new values will be recent, so check the last value first
        if let last = history.last, last <= sample {
            history.append(sample)
        } else {
            // Do a binary search in the sorted array and insert in the right place
            history.insertIntoSorted(sample)
        }
    }

    public func tree(from start: Timestamp? = nil, to end: Timestamp? = nil, depth: Int? = nil, limitPerNode: Int? = nil) -> Tree {
        let samples = samples(from: start, to: end, limit: limitPerNode)

        // Only return the value, if depth is reached
        if let depth, depth == 0 {
            return .init(samples: samples)
        }

        let newDepth = depth?.subtracting(1)
        let children: [PathComponent : Tree] = self.children.mapValues { child in
            child.tree(from: start, to: end, depth: newDepth, limitPerNode: limitPerNode)
        }
        return .init(samples: samples, children: children)
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
     - Returns: The values in the range, sorted from `start` to `end`, or by oldest first, if either is `nil`. If a limit is set, then the `limit` values counted from `start` (or oldest) are returned.
     */
    func samples(from start: Timestamp?, to end: Timestamp?, limit: Int?) -> [Sample] {
        guard let start else {
            // No start provided, so use beginning of time
            guard let end else {
                guard let limit else {
                    // No start, end, or limit, so return the full history
                    return history
                }
                // Limit the full history, return in ascending order (already sorted correctly)
                return Array(history.prefix(limit))
            }
            // No start, but end provided: descending order, end inclusive
            let endIndex = firstIndex(after: end)
            return selectDescending(lowerIndex: 0, higherIndex: endIndex, limit: limit)
        }

        guard let end else {
            // Start, but no end, so return in ascending order
            let startIndex = firstIndex(after: start)
            return selectAscending(start: startIndex, end: history.endIndex, limit: limit)
        }
        guard start < end else {
            // Reverse order requested
            // This case needs to be treated differently, due to start being exclusive and end inclusive
            return selectDescending(start: start, end: end, limit: limit)
        }
        // Both start and end given in "correct" order, so return ascending
        let startIndex = firstIndex(after: start)
        let endIndex = firstIndex(after: end)
        return selectAscending(start: startIndex, end: endIndex, limit: limit)
    }

    private func selectAscending(start startIndex: Int, end endIndex: Int, limit: Int?) -> [Sample] {
        // Move the end index if the range needs to be limited
        let limitedEndIndex = limit.map { min(endIndex, startIndex + $0) } ?? endIndex
        return Array(history[startIndex..<limitedEndIndex])
    }

    private func selectDescending(start: Timestamp, end: Timestamp, limit: Int?) -> [Sample] {
        // The lower index of the subsequence is given by `end`, since end < start
        // End is inclusive, so we find the first index larger than or equal to `end`
        let lowerIndex = history.partitioningIndex { $0.timestamp >= end }
        // The higher index is given by `start`, but exclusive.
        // Since we need the index after the last included element, we select the first index larger than or equal to `start`
        let higherIndex = history.partitioningIndex { $0.timestamp >= start }
        // Now we select the subrange in descending order, with the limit applied from the higher index
        return selectDescending(lowerIndex: lowerIndex, higherIndex: higherIndex, limit: limit)
    }

    private func selectDescending(lowerIndex: Int, higherIndex: Int, limit: Int?) -> [Sample] {
        // Move the higher index if the range needs to be limited
        let limitedLowerIndex = limit.map { max(lowerIndex, higherIndex - $0) } ?? lowerIndex
        // Reverse the subsequence, because the order is expected to be descending
        return Array(history[limitedLowerIndex..<higherIndex].reversed())
    }

    /// Return the history index of the first element larger than the given date
    private func firstIndex(after date: Timestamp) -> Int {
        // Find the first index in the array where the sample date is after the given date
        // If all values are smaller than or equal to the given date, then the end index is returned
        return history.partitioningIndex { $0.timestamp > date }
    }

    func delete(from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        // Delete samples at the node
        deleteSamples(from: start, to: end)

        // Delete child samples
        let newDepth = depth?.subtracting(1)
        for child in children.values {
            child.delete(from: start, to: end, depth: newDepth)
        }
    }

    func deleteSamples(from start: Timestamp?, to end: Timestamp?) {
        guard let start else {
            // No start provided, so use beginning of time
            guard let end else {
                // No end provided, so delete full history
                history.removeAll()
                return
            }
            // No start, but end provided
            let endIndex = firstIndex(after: end)
            history.removeSubrange(0..<endIndex)
            return
        }

        guard let end else {
            // Start, but no end, so return in ascending order
            let startIndex = firstIndex(after: start)
            history.removeSubrange(startIndex...)
            return
        }
        guard start < end else {
            // Reverse order requested
            // This case needs to be treated differently, due to start being exclusive and end inclusive
            let startIndex = history.partitioningIndex { $0.timestamp >= end }
            // The end index is given by `start`, but exclusive.
            // Since we need the index after the last included element, we select the first index larger than or equal to `start`
            let endIndex = history.partitioningIndex { $0.timestamp >= start }
            history.removeSubrange(startIndex..<endIndex)
            return
        }
        // Both start and end given in "correct" order
        let startIndex = firstIndex(after: start)
        let endIndex = firstIndex(after: end)
        // The start index is exclusive, and the end index is inclusive
        history.removeSubrange(startIndex..<endIndex)
    }
}