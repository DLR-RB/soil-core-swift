import Foundation

/**
 Combine messages with ids into trees.
 */
actor RemoteDataCollector {

    /// The number of nanoseconds until a batch times out
    private let batchTimeout: UInt64

    /// The receiver injesting updates from the remote component
    private var receiver: any Receiver

    /// The currently tracked batches, indexed by their id
    private var activeBatches: [Int : IncompleteReceivedTree] = [:]

    /**
     Create a handler to manage messages.
     */
    init(receiver: any Receiver, batchTimeout: TimeInterval) {
        self.receiver = receiver
        self.batchTimeout = UInt64(batchTimeout * 1_000_000_000)
    }

    /**
     Set the receiver for data received over the connection.
     - Parameter receiver: The receiver of the data coming in over this connection.
     */
    public func setReceiver(_ receiver: any Receiver) {
        self.receiver = receiver
    }

    /**
     Get the receiver of incoming messages of this connection.
     */
    public func getReceiver() -> any Receiver {
        return receiver
    }

    /**
     Create a task that times out after a while
     - Parameter id: The id of the batch that timed out
     - Note: The `cancel()` function is called with the provided id when the task reaches its timeout
     */
    private func startBatchTimeout(id: Int) -> Task<Void, Never> {
        let timeout = batchTimeout
        return Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout)

            guard !Task.isCancelled, let self else {
                return
            }
            await self.cancel(batch: id)
        }
    }

    /**
     Cancel an incomplete batch.
     - Parameter id: The id of the batch to cancel.
     - Returns: `true`, if the batch was found and canceled.
     */
    @discardableResult
    func cancel(batch id: Int) -> Bool {
        guard let batch = activeBatches[id] else {
            // No active batch, so we ignore the timeout
            return false
        }
        // Note: The batch is removed once `didComplete()` is called by the batch
        batch.finish()
        return true
    }

    /**
     Function called by each batch when it finishes.
     */
    private func didComplete(batch id: Int, with tree: any SampleTree, at path: Path) {
        activeBatches[id] = nil
        receiver.accept(tree, for: path)
    }

    /// The number of currently active batches
    var numberOfIncompleteBatches: Int {
        activeBatches.count
    }

    /**
     Indicate if a message batch with the given id is currently being received.
     - Parameter id: The id of the batch
     - Returns: `true`, if a batch with the id is in progress.
     */
    func hasIncompleteBatch(id: Int) -> Bool {
        activeBatches[id] != nil
    }
}

extension RemoteDataCollector: MessageReceiver {

    /**
     Process a received data message, which may update an existing batch, or create a new one.
     - Parameter message: The received data message
     */
    func didReceive(message: Message) {
        guard message.type == .data else {
            // Not a data message, so we ignore it
            return
        }
        guard let id = message.id else {
            // No batch id, so we just forward the message data
            receiver.accept(message.data, for: message.path)
            return
        }

        let batch = getOrCreateBatch(id: id)
        batch.update(with: message)
        if batch.hasReceivedAllExpectedMessages {
            batch.finish()
        }
    }

    /**
     Select or create a batch for an id.
     */
    private func getOrCreateBatch(id: Int) -> IncompleteReceivedTree {
        if let batch = activeBatches[id] {
            return batch
        }

        // No active batch, so we need to create a new one
        let timeoutTask = startBatchTimeout(id: id)

        let batch = IncompleteReceivedTree(
                timeout: timeoutTask) { [weak self] tree, path in
            guard let self else {
                return
            }
            Task {
                await self.didComplete(batch: id, with: tree, at: path)
            }
        }
        activeBatches[id] = batch
        return batch
    }
}
