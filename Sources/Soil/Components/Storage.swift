

/**
 A component that provides all operations required to store, retrieve, and delete data
 */
public protocol Storage: Provider, Receiver {

    /**
     Delete data from the storage.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Returns: A request that can be used to wait until completion
     */
    @discardableResult
    func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> Request
}
