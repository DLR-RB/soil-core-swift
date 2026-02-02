
/**
 An asynchronuous request.

 Use this request to execute an async function and optionally wait for the result.
 */
public final class AsyncRequest: Request {

    /// The task to complete with the request.
    private let task: Task<Void, Never>

    /**
     Execute an async function as a task within the request.
     - Parameter operation: The async function to complete with the request.
     */
    public init(_ operation: @escaping @Sendable () async -> Void) {
        self.task = Task {
            await operation()
        }
    }

    /**
     Wait for the request to complete
     */
    public func wait() async {
        await task.value
    }
}