
/**
 An internal class that captures a callback to act as a receiver
 */
final class CallbackReceiver {

    /// The stored callback
    let callback: @Sendable (_ samples: SampleTree, _ path: Path) async -> Void

    /**
     Create a receiver with a callback.
     */
    init(callback: @escaping @Sendable (_ samples: SampleTree, _ path: Path) async -> Void) {
        self.callback = callback
    }
}

extension CallbackReceiver: Receiver {

    /**
     Receive a tree for a path.

     Components may choose to ignore samples due to access rights or other reasons.
     - Parameter tree: The tree to store for the path.
     - Parameter path: The path associated with the samples
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
       To wait until the receive is completed, await the returned request.
     */
    func receive(_ tree: SampleTree, for path: Path) -> any Request {
        AsyncRequest {
            await self.callback(tree, path)
        }
    }
}
