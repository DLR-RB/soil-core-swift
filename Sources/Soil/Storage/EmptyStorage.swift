
/**
 A dummy storage that implement the interface but does not hold any data.
 */
public final class EmptyStorage {

    /**
     Pretends to receive the data, but discards it.
     - Parameter tree: The tree with the samples to store.
     - Parameter path: The path of the tree.
     */
    public func receive(_ tree: Tree, for path: Path) {
        // Does not store the data
    }

    /**
     Returns an empty tree for all data requests
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
        .empty
    }

    /**
     Ignores deletion requests since there is no data to delete.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     */
    public func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        // Does not have any data to delete
    }
}