
/**
 A request for data that is not completed
 */
final class DataRequest {

    /// The path contained in the request
    let path: Path

    /// The (start) time of the requested interval
    let start: Timestamp?

    /// The end time of the requested interval
    let end: Timestamp?

    /// The requested depth of the data to provide
    let depth: Int?

    /// The maximum number of samples per node
    let limit: Int?

    /**
     The tree containing the received samples while waiting for more responses

     - Note: The tree is constructed for the root path
     */
    private let tree: MutableSampleTree = .init()

    /// The continuation to execute when the request is completed or timed out
    let continuation: CheckedContinuation<SampleTree, Never>

    /// The timeout task to cancel if the request is completed before timing out
    private let timeout: Task<Void, Never>

    /// The expected number of response messages, extracted from received responses
    var expectedMessages: Int?

    /// The number of already received messages for this request
    var receivedMessages = 0

    /**
     Create a request for tracking
     */
    init(path: Path,
         start: Timestamp?,
         end: Timestamp?,
         depth: Int?,
         limit: Int?,
         continuation: CheckedContinuation<SampleTree, Never>,
         timeout: Task<Void, Never>
    ) {
        self.path = path
        self.start = start
        self.end = end
        self.depth = depth
        self.limit = limit
        self.continuation = continuation
        self.timeout = timeout
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
        let tree = self.tree.existingNode(for: path)?.tree ?? ImmutableSampleTree()
        continuation.resume(returning: tree)
    }

    /**
     Check that the path in the response matches the request.

     For all requests the response must either:
     - Match perfectly for inclusions, exclusions and history requests
     - Be a sub-path of the request for value requests within the requested depth
     */
    private func matches(_ path: Path) -> Bool {
        // All responses for a value request must be in the requested sub-tree
        guard path.hasPrefix(self.path) else {
            return false
        }
        guard let depth else {
            // Without a depth, the only requirement is to be within the sub-tree
            return true
        }
        // With a depth, the remaining path must not be too long
        let remainingDepth = path.count - self.path.count
        return remainingDepth <= depth
    }

    /**
     Update the active request, run the callback, and check if the request is completed.
     - Note: This function expects that:
       - the message is a data message
       - the component id matches the sender of the message
       - the request id matches this request.
     - Returns: `true`, if the request matched and was processed
     */
    @discardableResult
    func update(with response: Message) -> Bool {
        guard matches(response.path) else {
            // TODO: Should we still update the expected message count if the path is incorrect?
            // The misbehaving client may include this message in the count,
            // which would cause the request to not be completed.

            // Note: We could also end up here if a malicious client attempts to use a request
            // to respond with unrelated data that it's not allowed to write, in an attempt
            // to circumvent access restrictions
            return false
        }
        updateExpectedMessageCount(response.count)
        receivedMessages += 1

        // Insert the data into the tree
        // TODO: Limit the number of samples, and the date interval
        tree.merge(response.data, at: response.path)
        return true
    }

    /**
     Restrict the samples to the requested interval
     */
    private func limit(_ samples: [Sample]) -> [Sample] {
        guard let start else {
            guard let end else {
                // No interval given, so all samples are relevant
                return samples
            }
            // Only start given, so remove all after end (end is inclusive)
            return samples.filter { $0.time <= end }
        }

        guard let end else {
            // Only start given, so remove all before start (start is exclusive)
            return samples.filter { $0.time > start }
        }

        guard start < end else {
            // Reverse order (start is exclusive, end is inclusive)
            return samples.filter { $0.time < start && $0.time >= end }
        }
        // "Normal" order (start is exclusive, end is inclusive)
        return samples.filter { $0.time > start && $0.time <= end }
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
