
/**
 A request for data that is not completed
 */
final class IncompleteReceivedTree {

    /**
     The tree containing the received samples while waiting for more responses

     - Note: The tree is constructed for the root path
     */
    private let tree: MutableSampleTree = .init()

    /// The receiver to forward the tree to on completion
    let onComplete: (_ tree: any SampleTree, _ path: Path) -> Void

    /// The timeout task to cancel if the batch is completed before timing out
    private let timeout: Task<Void, Never>

    /// The expected number of response messages, extracted from received responses
    var expectedMessages: Int?

    /// The number of already received messages for this batch
    var receivedMessages = 0

    /**
     Create a request for tracking
     */
    init(timeout: Task<Void, Never>,
         onComplete: @escaping (_ tree: any SampleTree, _ path: Path) -> Void
    ) {
        self.timeout = timeout
        self.onComplete = onComplete
    }

    /**
     Complete the request.

     This function is called regardless if the request is completed or a timeout is reached.
     The timeout task will be canceled (may already be completed), and the continuation is resumed with the available data.
     */
    func finish() {
        timeout.cancel()
        // Here we need get the tree for the correct path,
        // not the tree at the root
        let (path, tree) = self.tree.containedTree()
        onComplete(tree.tree, path)
    }

    /**
     Update the active request, run the callback, and check if the request is completed.
     - Note: This function expects that:
       - the message is a data message
       - the component id matches the sender of the message
       - the request id matches this request.
     */
    func update(with response: Message) {
        updateExpectedMessageCount(response.count)
        receivedMessages += 1

        tree.merge(response.data, at: response.path)
    }

    /**
     Update the number of expected messages if the response contains this info.
     - Note: If a mismatching count is received, then the larger one is used.
     */
    private func updateExpectedMessageCount(_ count: Int?) {
        guard let count else {
            // Keep the existing count, since no new one received
            return
        }
        guard let expectedMessages else {
            // No previous count, so set the received one
            expectedMessages = count
            return
        }
        if count == expectedMessages {
            return
        }
        // The previous count does not match the received one, which is an application error.
        // The count should always be the same for one request.
        // We just use the higher value, since the component may have "found" additional messages to send.
        // TODO: Propagate warning about count mismatch
        if count > expectedMessages {
            self.expectedMessages = count
        }
    }

    /**
     Indicate if the request is completed

     The request is assumed completed if the number of received messages matches the stated number in the messages.
     */
    var hasReceivedAllExpectedMessages: Bool {
        receivedMessages == expectedMessages
    }
}
