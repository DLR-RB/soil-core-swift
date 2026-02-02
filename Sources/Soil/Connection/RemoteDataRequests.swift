
/**
 Handle active requests to a remote storage component
 */
final class RemoteDataRequests {

    /**
     Create a handler to manage requests.
     */
    init() { }

    /// The currently active requests, indexed by their id
    private var activeRequests: [Int : DataRequest] = [:]

    /**
     Add an active request.
     - Parameter request: The new request
     - Parameter id: The unique request id
     - Note: An existing request for the id will be canceled.
     */
    func add(_ request: DataRequest, for id: Int) {
        if let previous = activeRequests[id] {
            previous.finish()
        }
        // Note: Timeout for requests are handled by the caller.
        // Each request includes a timeout task, which will be canceled
        // when the request is completed.
        // If a timeout is reached, then `cancel()` will be called by the caller.
        activeRequests[id] = request
    }

    /**
     Process a received message and update a matching request.
     - Parameter message: The message to process
     - Returns: `true`, if a matching request was updated.
     */
    @discardableResult
    func didReceive(_ response: Message) -> Bool {
        guard let id = response.id else {
            // No request id, so we ignore the message
            return false
        }
        guard let request = activeRequests[id] else {
            // No active request, so we ignore the message
            return false
        }

        request.update(with: response)

        // Remove request if completed
        if request.hasReceivedAllExpectedMessages {
            activeRequests[id] = nil
            request.finish()
        }
        return true
    }

    /**
     Cancel an active request.
     - Parameter id: The id of the request to cancel.
     - Returns: `true`, if the request was found and canceled.
     */
    @discardableResult
    func cancel(request id: Int) -> Bool {
        guard let request = activeRequests[id] else {
            // No active request, so we ignore the timeout
            return false
        }
        request.finish()
        return true
    }

    /// The number of currently active requests
    var numberOfRequests: Int {
        activeRequests.count
    }

    /**
     Indicate if a request with the given id is active.
     - Parameter id: The id of the request
     - Returns: `true`, if a request with the id is active.
     */
    func hasRequest(id: Int) -> Bool {
        activeRequests[id] != nil
    }
}
