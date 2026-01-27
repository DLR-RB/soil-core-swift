
/**
 Manages requests made to other components, tracking status and completions.

 - History requests: Track missing messages
 - Value requests: Track missing messages
 - Subscriptions/exclusions: Track acknowledgement

 Request managers are generic over the component id, which is determined by the transport layer.
 */
final class RequestManager<ComponentId: Hashable> {

    /// The active requests for each component, indexed by component id
    private var activeRequests: [ComponentId : ComponentRequests<ComponentId>] = [:]

    /**
     Create a manager for requests.
     */
    init() { }

    // TODO: Receive response if the message was sent
    /// The callback registered by the client user to send messages to components
    private var sendCallback: ((_ receiver: ComponentId, _ message: Message) -> Void)?

    /**
     Set the callback to be informed about outgoing messages to components.

     This callback is required to process deliver responses and requests from the client.
     - Parameter callback: The closure to call with messages that should be sent
     - Parameter receiver: The id of the component that should receive the message
     - Parameter message: The message to send to the component
     */
    func setMessageCallback(_ callback: @escaping (_ receiver: ComponentId, _ message: Message) -> Void) {
        sendCallback = callback
    }

    /**
     Remove all pending requests for a component.
     - Parameter component: The id of the component
     */
    func discardRequests(of component: ComponentId) {
        activeRequests[component] = nil
    }

    /**
     Send a message to a component.
     - Parameter message: The message to send.
     - Parameter component: The id of the component to send the message to
     - Note: If no message callback is available, then the message is discarded.
     - Returns: `true` if the message was handed to the transport layer.
     */
    @discardableResult
    private func send(message: Message, to component: ComponentId) -> Bool {
        guard let sendCallback else {
            return false
        }
        sendCallback(component, message)
        return true
    }

    /**
     The function called by the client with new messages, to match them to requests.
     - Parameter message: The received message
     - Parameter component: The id of the component that sent the message.
     - Returns: `true`, if the message was associated with a request, otherwise `false`
     */
    @discardableResult
    func didReceive(message: Message, from component: ComponentId) -> Bool {
        guard message.type == .data else {
            // We only care about value messages, which can be responses to requests
            return false
        }
        guard let componentRequests = activeRequests[component] else {
            // No active requests for component
            return false
        }

        // Note: We don't remove the handler for this component, even if no more requests are in progress
        // The assumption is that more requests will follow in the future
        // or that cleanup will be done by calling `discardRequests(of:)` when the component disconnects
        return componentRequests.findRequestAndUpdate(with: message)
    }

    /**
     Get the request id for a component.

     The request id is incremented from 1 (independently for each component),
     while a connection to the component is active.
     - Note: This function already creates the request handler for the component
     */
    private func nextRequestId(for component: ComponentId) -> Int {
        activeRequests[component, default: .init()].nextRequestId()
    }

    /// Store a performed request with a callback for response processing
    private func store(_ request: Request<ComponentId>, callback: @escaping (Response<ComponentId>) -> Void) {
        // Note: At this point the request handler for the component should be created
        // from calling `nextRequestId()`
        activeRequests[request.component, default: .init()].add(request: request, callback: callback)
    }

    // MARK: Requests

    /**
     Make a request, and track it if a callback is provided.
     */
    private func makeAndTrackRequest(
        _ type: RequestType,
        to path: Path,
        of component: ComponentId,
        responses: @escaping (Response<ComponentId>) -> Void
    ) -> Int {
        let id = nextRequestId(for: component)
        executeRequest(type, to: path, of: component, id: id, responses: responses)
        return id
    }

    private func executeRequest(
        _ type: RequestType,
        to path: Path,
        of component: ComponentId,
        id: Int,
        responses: @escaping (Response<ComponentId>) -> Void
    ) {
        let message = switch type {
            case .exclude(let depth):
                Message.exclude(path, depth: depth, from: id)
            case .include(let depth):
                Message.include(path, depth: depth, in: id)
            case .deleteSubscriptionRules(let depth):
                Message.deleteRules(at: path, depth: depth, for: id)
            case .data(let start, let end, let depth, let limit):
                Message.request(path, from: start, to: end, limit: limit, depth: depth, id: id)
        }

        defer { send(message: message, to: component) }

        let request =  Request(
            component: component,
            id: id,
            path: path,
            type: type)

        store(request, callback: responses)
    }

    /**
     Create and track a request to subscribe to a path of a component.
     - Paramete path: The path to which to subscribe
     - Parameter component: The id of the component which is targeted.
     - Parameter depth: The number of levels below the path to include in the subscription
     - Parameter confirmationReceived: A closure to call when the response is received.
     - Parameter subscription: The id of the subscription to update
     */
    func include(
        _ path: Path,
        depth: Int? = nil,
        of component: ComponentId,
        in subscription: Int,
        confirmationReceived: @escaping () -> Void
    ) {
        executeRequest(
            .include(depth: depth),
            to: path,
            of: component,
            id: subscription) { _ in
                confirmationReceived()
            }
    }

    /**
     Create and track a request to unsubscribe or perform a subscription exclusion for a path.
     - Paramete path: The path from which to unsubscribe or to exclude
     - Parameter component: The id of the component which is targeted.
     - Parameter depth: The depth of the original subscription or the depth to exclude
     - Parameter confirmationReceived: A closure to call when the response is received.
     - Parameter subscription: The id of the subscription to update
     */
    func exclude(
        from path: Path,
        of component: ComponentId,
        depth: Int? = nil,
        in subscription: Int,
        confirmationReceived: @escaping () -> Void
    ) {
        executeRequest(
            .exclude(depth: depth),
            to: path,
            of: component,
            id: subscription) { _ in
            confirmationReceived()
        }
    }

    /**
     Create and track a request to delete a subscription.
     - Parameter component: The id of the component which is targeted.
     - Parameter depth: The depth of the original subscription or the depth to exclude
     - Parameter confirmationReceived: A closure to call when the response is received.
     - Parameter subscription: The id of the subscription to update
     */
    func deleteRules(
        at path: Path,
        depth: Int? = nil,
        for component: ComponentId,
        in subscription: Int,
        confirmationReceived: @escaping () -> Void
    ) {
        executeRequest(
            .deleteSubscriptionRules(depth: depth),
            to: path,
            of: component,
            id: subscription) { _ in
            confirmationReceived()
        }
    }

    /**
     Create and track a request for a value of a component.
     - Parameter path: The path for which to request the value
     - Parameter component: The id of the component to which the request is made
     - Parameter start: The start date of the requested interval (exclusive)
     - Parameter end: The end date of the requested interval (inclusive)
     - Parameter limit: The maximum number of samples to return (counted from `start`)
     - Parameter depth: The number of levels below the requested node for which to return samples, defaults to no limit
     - Parameter receivedSample: The closure to call with the received values. May be called multiple times.
     - Returns: The id of the performed request.
     */
    @discardableResult
    func requestData(
        at path: Path,
        of component: ComponentId,
        from start: Timestamp? = nil,
        to end: Timestamp? = nil,
        limit: Int? = nil,
        depth: Int? = nil,
        receivedSample: @escaping (_ path: Path, _ sample: Sample) -> Void
    ) -> Int {
        makeAndTrackRequest(
            .data(start: start, end: end, depth: depth, limit: limit),
            to: path,
            of: component) { response in
                if let value = response.value {
                    let sample = Sample(value: value, timestamp: response.timestamp ?? .current())
                    receivedSample(response.request.path, sample)
                }
                for sample in response.samples {
                    receivedSample(response.path, sample)
                }
            }
    }

    // MARK: Request management

    /**
     Indicate if a request is still being tracked.
     - Parameter id: The id of the request
     - Parameter component: The id of the component to which the request was made
     - Returns: `true`, if the request is still pending
     */
    func hasPendingRequest(id: Int, component: ComponentId) -> Bool {
        activeRequests[component]?.hasPendingRequest(id: id) ?? false
    }

    /**
     Remove a request so that it's no longer tracked
     - Parameter id: The id of the request
     - Parameter component: The id of the component to which the request was made
     */
    func cancelPendingRequest(id: Int, component: ComponentId) {
        activeRequests[component]?.cancelRequest(id: id)
    }
}