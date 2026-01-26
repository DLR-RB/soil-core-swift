

/**
 A simple storage implementation that keeps all values in memory.

 Internally, the storage is organized in a tree, with an array of all samples for a path stored in each node.

 The database storage is not optimized for extreme performance.
 Each sample for a tree node is inserted separately, which may result in many array operations, even if batch inserts may be possible.
 The assumption is that mostly current samples will be received, which can be appended to the sorted internal array of history values.
 */
public final class InMemoryStorage {

    /// All historic values at this node, sorted by oldest first
    private var history: [Sample] = []

    /**
     The nodes immediately below this node in the tree,
     indexed by their path component.
     */
    private var children: [PathComponent: InMemoryStorage] = [:]

    /**
     Create an in-memory storage.
     */
    public init() { }

    // MARK: Node selection

    /**
     Get a node for a path below the current node, if it exists.

     This function is used for read and delete operations, and does not create any new nodes.
     - Parameter path: The path to select within the tree.
     - Returns: The node at the path, if it exists.
     */
    private func existingNode(for path: Path) -> InMemoryStorage? {
        var current = self
        for component in path {
            guard let child = current.existingChild(named: component) else {
                return nil
            }
            current = child
        }
        return current
    }

    /**
     Select or create a node for the given path.

     This function is used for write operations, when the node is required to be present.
     - Parameter path: The path to select within the tree.
     - Returns: The node at the path, created if it did not exist yet.
     */
    private func getOrCreateNode(for path: Path) -> InMemoryStorage {
        var current = self
        for component in path {
            current = current.child(named: component)
        }
        return current
    }

    /**
     Select a child of this node with a given name.

     The child will be created, if it doesn't exist.
     This function is used for write operations.
     - Parameter name: The name of the child.
     - Returns: The node of the child.
     */
    private func child(named name: PathComponent) -> InMemoryStorage {
        if let child = existingChild(named: name) {
            return child
        }
        let child = InMemoryStorage()
        children[name] = child
        return child
    }

    /**
     Get a node of a child, if it exists.

     This function is used for read and delete operations.
     - Parameter name: The name of the child.
     - Returns: The child node, if it exists.
     */
    private func existingChild(named name: PathComponent) -> InMemoryStorage? {
        children[name]
    }

    /**
     Save a tree at this node.

     Inserts all samples of the tree root, and recurses into the children to store the full tree.
     - Parameter tree: The tree to save for this node.
     */
    private func save(_ tree: Tree) {
        for sample in tree.samples {
            insertSampleIntoHistory(sample)
        }

        // Recurse into the tree to store all samples
        for (name, subTree) in tree.children {
            child(named: name).save(subTree)
        }
    }

    /**
     Insert a single sample into the history at this node.

     The sample is inserted at the correct index to keep the array sorted.
     - Parameter sample: The sample to insert
     */
    private func insertSampleIntoHistory(_ sample: Sample) {
        // We assume that most new values will be recent, so check the last value first
        if let last = history.last, last <= sample {
            history.append(sample)
        } else {
            // Do a binary search in the sorted array and insert in the right place
            history.insertIntoSorted(sample)
        }
    }

    /**
     Construct a tree in a provided interval with a maximum depth.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter depth: The number of levels in the sub-tree to include
     - Parameter limitPerNode: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted from `start` to `end`, or by oldest first, if either is `nil`.
       If a limit is set, then the `limit` values counted from `start` (or oldest) are returned.
     */
    private func tree(from start: Timestamp? = nil, to end: Timestamp? = nil, depth: Int? = nil, limitPerNode: Int? = nil) -> Tree {
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
            return selectDescending(0..<endIndex, limit: limit)
        }

        guard let end else {
            // Start, but no end, so return in ascending order
            let startIndex = firstIndex(after: start)
            return selectAscending(startIndex..<history.endIndex, limit: limit)
        }
        guard start < end else {
            // Reverse order requested
            // This case needs to be treated differently, due to start being exclusive and end inclusive
            return selectDescending(from: end, to: start, limit: limit)
        }
        // Both start and end given in "correct" order, so return ascending
        let startIndex = firstIndex(after: start)
        let endIndex = firstIndex(after: end)
        return selectAscending(startIndex..<endIndex, limit: limit)
    }

    /**
     Select all samples between two indices in storage (ascending) order, limited to a maximum count.
     - Parameter range: The range to select from `history`
     - Parameter limit: The optional limit, applied from the lower end of the range
     */
    private func selectAscending(_ range: Range<Int>, limit: Int?) -> [Sample] {
        // Move the end index if the range needs to be limited
        let limitedEndIndex = limit.map { min(range.upperBound, range.lowerBound + $0) } ?? range.upperBound
        return Array(history[range.lowerBound..<limitedEndIndex])
    }

    /**
     Select samples in the history in a date range in descending order, optionally limited to a maximum count.
     - Parameter start: The lower bound of the interval (inclusive)
     - Parameter end: The upper bound of the interval (exclusive)
     - Parameter limit: The optional count limit to apply, returning only the `limit` newest samples.
     */
    private func selectDescending(from start: Timestamp, to end: Timestamp, limit: Int?) -> [Sample] {
        // The lower index of the subsequence is given by `start`
        // Start is inclusive, so we find the first index larger than or equal to `start`
        let lowerIndex = history.partitioningIndex { $0.timestamp >= start }
        // The higher index is given by `end`, but exclusive.
        // Since we need the index after the last included element, we select the first index larger than or equal to `end`
        let higherIndex = history.partitioningIndex { $0.timestamp >= end }
        // Now we select the subrange in descending order, with the limit applied from the higher index
        return selectDescending(lowerIndex..<higherIndex, limit: limit)
    }

    /**
     Select all samples between two indices in reverse (descending) order, limited to a maximum count.

     - Note: The lower bound is inclusive, while the upper bound is exclusive.
     - Parameter range: The range to select from `history`
     - Parameter limit: The optional limit, applied from the upper end of the range
     */
    private func selectDescending(_ range: Range<Int>, limit: Int?) -> [Sample] {
        // Move the higher index if the range needs to be limited
        let limitedLowerIndex = limit.map { max(range.lowerBound, range.upperBound - $0) } ?? range.lowerBound
        // Reverse the subsequence, because the order is expected to be descending
        return Array(history[limitedLowerIndex..<range.upperBound].reversed())
    }

    /// Return the history index of the first element larger than the given date
    private func firstIndex(after date: Timestamp) -> Int {
        // Find the first index in the array where the sample date is after the given date
        // If all values are smaller than or equal to the given date, then the end index is returned
        return history.partitioningIndex { $0.timestamp > date }
    }

    /**
     Recursively delete all samples in an interval, with a maximum depth.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below this node
     */
    func delete(from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        // Delete samples at this node
        deleteSamples(from: start, to: end)

        // Recurse to delete child samples
        let newDepth = depth?.subtracting(1)
        for child in children.values {
            child.delete(from: start, to: end, depth: newDepth)
        }
    }

    /**
     Delete all samples at the current node in the given range.

     The deletion works as follows:
     - If neither `start` nor `end` is provided, then all samples are deleted.
     - If only `end` is provided, then all samples with timestamps before `end` are removed (`end` is exclusive)
     - If only `start` is provided, then all values with timestamps after an including `start` are deleted (`start` is inclusive)
     - If both `start` and `end` are provided, then all values between `start` and `end` are deleted (`start` is inclusive, `end` is exclusive)
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     */
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
            // Start, but no end, so delete all values after an including `start`
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

// MARK: Storage

extension InMemoryStorage: Storage {

    /**
     Save the samples of a tree at a path.

     This function searches for the correct node in the tree, and inserts the tree.
     This includes inserting the provided values at the node, and then traversing the provided tree further, until all samples are stored.
     - Parameter tree: The tree with the samples to store.
     - Parameter path: The path of the tree.
     */
    public func receive(_ tree: Tree, for path: Path) {
        getOrCreateNode(for: path).save(tree)
    }

    /**
     Get the tree of a path within a date range, including sub-paths

     For each node, this function returns the samples in the specified date range.
     - Parameter path: The requested path
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter depth: The number of levels in the sub-tree to include
     - Parameter limitPerNode: The maximum number of values to return for each node in the tree (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted from `start` to `end`, or by oldest first, if either is `nil`.
       If a limit is set, then the `limit` values counted in sort order are returned.
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

    /**
     Delete data from the storage.

     The function searches for the correct node in the tree,
     and removes all applicable values from the historic samples at this node.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     */
    public func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        existingNode(for: path)?.delete(from: start, to: end, depth: depth)
    }
}
