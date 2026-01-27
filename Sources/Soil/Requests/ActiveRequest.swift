

/**
 A request to a component that has not been completed
 */
final class ActiveRequest<ComponentId> {

    /// The request that was sent to the component
    let request: Request<ComponentId>

    /// The number of messages received for this request
    var receivedMessages: Int = 0

    /**
     The number of messages expected for this request

     This number is received with the first message via the `count` property,
     if the component supports it.
     It may also be deduced from the request, e.g. when requesting a single value or for subscriptions
     */
    var expectedMessages: Int?

    /// The closure to call when a message for the request is received
    let callback: (Response<ComponentId>) -> Void

    /**
     Create an active request with a callback
     - Parameter request: The information about the transmitted request
     - Parameter callback: The closure to call when the request receives responses
     */
    init(request: Request<ComponentId>, callback: @escaping (Response<ComponentId>) -> Void) {
        self.request = request
        self.callback = callback
        self.expectedMessages = request.type.expectedMessages
    }

    /**
     Update the active request, run the callback, and check if the request is completed.
     - Note: This function expects that:
       - the message is a data message
       - the component id matches the sender of the message
       - the request id matches this request.
     */
    func update(with message: Message) {
        guard requestPath(matches: message.path) else {
            // TODO: Propagate warning instead of quietly ignoring the error

            // TODO: Should we still update the expected message count if the path is incorrect?
            // The misbehaving client may include this message in the count,
            // which would cause the request to not be completed.
            return
        }
        updateExpectedMessageCount(message.count)
        receivedMessages += 1
        let response = Response(
            request: request,
            path: message.path,
            value: message.value,
            timestamp: message.time,
            samples: message.samples ?? [],
            isCompleted: isCompleted)
        callback(response)
    }

    /**
     Check that the path in the response matches the request.

     For all requests the response must either:
     - Match perfectly for inclusions, exclusions and history requests
     - Be a sub-path of the request for value requests within the requested depth
     */
    private func requestPath(matches path: Path) -> Bool {
        switch request.type {
        case .data(_, _, let depth, _):
            // All responses for a value request must be in the requested sub-tree
            guard path.hasPrefix(request.path) else {
                return false
            }
            guard let depth else {
                // Without a depth, the only requirement is to be within the sub-tree
                return true
            }
            // With a depth, the remaining path must not be too long
            let remainingDepth = path.count - request.path.count
            return remainingDepth <= depth
        case .include, .exclude:
            // For subscriptions, exclusions, and history requests, we expect the exact path
            return path == request.path
        case .deleteSubscriptionRules:
            // Response matches if id matches
            return true
        }
    }

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
    var isCompleted: Bool {
        receivedMessages == expectedMessages
    }
}
