
/**
 An asynchronuous request.

 Use this request to execute an async function and optionally wait for the result.
 */
actor AsyncRequest: Request {

    private var continuation: CheckedContinuation<Void, Never>?

    private var isDone = false

    /**
     Execute an async function as a task within the request.
     */
    init(_ operation: @escaping @Sendable () async -> Void) {
        Task {
            await operation()
            await self.complete()
        }
    }

    private func complete() {
        self.isDone = true
        self.continuation?.resume()
    }

    func wait() async {
        if isDone { return }
        await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }
}
