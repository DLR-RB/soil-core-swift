
/**
 Handle active requests to a remote storage component
 */
final class RemoteDataRequests {

    init() { }

    private var activeRequests: [Int : DataRequest] = [:]

    func add(_ request: DataRequest, for id: Int) {
        if let previous = activeRequests[id] {
            previous.finish()
        }
        activeRequests[id] = request

        // TODO: Add timeout function
    }

    func didReceive(_ response: Message) {
        guard let id = response.id else {
            // No request id, so we ignore the message
            return
        }
        guard let request = activeRequests[id] else {
            // No active request, so we ignore the message
            return
        }

        request.update(with: response)

        guard request.hasReceivedAllExpectedMessages else {
            return
        }

        activeRequests[id] = nil
        request.finish()
    }

    func cancel(request id: Int) {
        guard let request = activeRequests[id] else {
            // No active request, so we ignore the timeout
            return
        }
        request.finish()
    }
}
