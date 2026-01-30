
/**
 An asynchronuous request.

 Use this request to execute an async function and optionally wait for the result.
 */
final class AsyncRequest: Request {

    let task: Task<Void, Never>

    /**
     Execute an async function as a task within the request.
     */
    init(_ operation: @escaping @Sendable () async -> Void) {
        self.task = Task {
            await operation()
        }
    }

    func wait() async {
        await task.value
    }
}