

/**
 Contains all active requests currently tracked for one component.
 */
final class ComponentRequests<ComponentId> {

    /// The active requests for the component, indexed by the request id
    private var requests: [Int : ActiveRequest<ComponentId>] = [:]

    /*
     The id used for the most recent request

     This id is always incremented for the next request,
     so that the first request of the component has id `1`.
     The request id resets if the component is disconnected.
     */
    private var lastId = 0

    /**
     Create a structure to track requests to a component.
     */
    init() { }

    /**
     Get the request id for the component.

     The request id is incremented from 1 (independently for each component),
     while a connection to the component is active.
     */
    func nextRequestId() -> Int {
        lastId += 1
        return lastId
    }

    /// Indicate that all requests for this component are completed
    var hasCompletedAllRequests: Bool {
        requests.isEmpty
    }

    /**
     Indicate if a request is still being tracked.
     - Parameter id: The id of the request
     - Returns: `true`, if the request is still pending
     */
    func hasPendingRequest(id: Int) -> Bool {
        // Note: We could check the isCompleted flag of an existing request,
        // but requests are automatically removed if they are completed after each processed message.
        requests[id] != nil
    }

    /**
     Remove a request so that it's no longer tracked
     - Parameter id: The id of the request
     */
    func cancelRequest(id: Int) {
        requests[id] = nil
    }

    /**
     Add an active request.
     - Note: This function assumes that the request was made to the component associated with this handler.
     */
    func add(request: Request<ComponentId>, callback: @escaping (Response<ComponentId>) -> Void) {
        requests[request.id] = .init(request: request, callback: callback)
    }

    /**
     Find the active request matching the message and execute the callback.
     - Returns: `true`, if the message was associated with an active request, otherwise `false`
     - Note: This function expects that:
        - the message is a value message
        - the component id matches the sender of the message
     */
    func findRequestAndUpdate(with message: Message) -> Bool {
        guard let id = message.id else {
            // If the request does not contain a request id,
            // either the component doesn't add it, or the message is not relevant
            return findRequest(for: message)
        }
        guard let activeRequest = requests[id] else {
            // No active request found for the id, ignore the message
            return false
        }
        activeRequest.update(with: message)

        // Remove the request if all messages are received.
        if activeRequest.isCompleted {
            requests[id] = nil
        }
        return true
    }

    /**
     Attempt to find an active request that matches the received message.

     This function is called if the message contains no request id.
     It might match a request (then the component does not support request ids),
     or it might be unrelated to performed requests, e.g. value push messages, or subscription updates.
     - Returns: `true`, if an associated request was found, otherwise false
     */
    private func findRequest(for message: Message) -> Bool {
        // Attempt to find an active request that matches the received message
        // It might be possible to check the paths of request and response for matches
        // TODO: Implement
        return false
    }
}
