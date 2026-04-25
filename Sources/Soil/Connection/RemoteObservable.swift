
/**
 Connect to an observable component via a transport layer.
 */
public actor RemoteObservable {

    /// The connection to the remote component via the underlying transport layer
    public let connection: any MessageConnection

    /// The active subscriptions, indexed by the subscription id
    private var subscriptions: [Int : RemoteSubscriptionData] = [:]

    /**
     Create an interface to work with a remote observable component.
     - Parameter connection: The connection to the component
     */
    public init(connection: any MessageConnection) async {
        self.connection = connection

        // Register to receive messages from the component
        await connection.setReceiver(self)
    }

    // MARK: Subscription ID

    /*
     The id used for the most recent subscription

     This id is always incremented for the next subscription,
     so that the first subscription of the component has id `1`.
     */
    private var lastSubscriptionId = 0

    /**
     Get the subscription id for the component.

     The subscription id is incremented from 1,
     while a connection to the component is active.
     - Returns: The id to use for the next subscription.
     */
    private func nextSubscriptionId() -> Int {
        lastSubscriptionId += 1
        return lastSubscriptionId
    }

    // MARK: Transport layer interaction

    /**
     Process a data message, by checking which request it matches
     - Parameter message: The received data message
     */
    private func didReceive(data message: Message) {
        // Note: We know that the message is a data message

        // Check all subscriptions for matches
        for data in subscriptions.values {
            // Reduce the received tree according to the subscription rules
            guard let reduced = data.rules.reduce(message.data, for: message.path) else {
                continue
            }
            // Note: We don't wait for subscription receiver requests
            data.receiver.receive(reduced, for: message.path)
        }
    }

    /**
     Send a message to the component.
     - Parameter message: The message to send.
     - Note: If no message callback is available, then the message is discarded.
     - Returns: The request to send the message
     */
    @discardableResult
    private func send(_ message: Message) -> any Request {
        connection.send(message: message)
    }

    // MARK: Subscription management

    /**
     Internal function called by a subscription object to include a path in a subscription.

     If the subscription exists, then a request to include the path will be sent to the remote,
     and the internal subscription state will be updated.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to modify
     - Returns: The request to send the message to the component, or an already completed request.
     */
     fileprivate func include(_ path: Path, depth: Int?, for id: Int) -> any Request {
        guard let data = subscriptions[id] else {
            return CompletedRequest()
        }
        // Track the state of the subscription internally,
        // to ensure that updates are properly matched
        data.rules.include(path, depth: depth)

        return send(.include(path, depth: depth, in: id))
    }

    /**
     Internal function called by a subscription object to exclude a path from a subscription.

     If the subscription exists, then a request to exclude the path will be sent to the remote,
     and the internal subscription state will be updated.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to modify
     - Returns: The request to send the message to the component, or an already completed request.
     */
    fileprivate func exclude(_ path: Path, depth: Int?, for id: Int) -> any Request {
        guard let data = subscriptions[id] else {
            return CompletedRequest()
        }
        // Track the state of the subscription internally,
        // to ensure that updates are properly matched
        data.rules.exclude(path, depth: depth)

        return send(.exclude(path, depth: depth, from: id))
    }

    /**
     Internal function called by a subscription object to delete rules of a subscription.

     If the subscription exists, then a request to remove the rules will be sent to the remote,
     and the internal subscription state will be updated.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to modify
     - Returns: The request to send the message to the component, or an already completed request.
     */
    fileprivate func deleteRules(at path: Path, depth: Int?, for id: Int) -> any Request {
        guard let data = subscriptions[id] else {
            return CompletedRequest()
        }
        // Track the state of the subscription internally,
        // to ensure that updates are properly matched
        data.rules.deleteRules(at: path, depth: depth)

        return send(.deleteRules(at: path, depth: depth, for: id))
    }

    /**
     Internal function called by a subscription object to cancel a subscription.

     If the subscription exists, then a request to remove all rules will be sent to the remote,
     to deactivate the subscription.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to cancel
     - Returns: The request to send the message to the component, or an already completed request.
     */
    fileprivate func cancel(_ id: Int) -> any Request {
        guard subscriptions[id] != nil else {
            return CompletedRequest()
        }
        // Remove the subscription
        subscriptions[id] = nil

        // Remove all rules on the connected remote
        return send(.deleteRules(at: [], depth: nil, for: id))
    }
}

// MARK: Message receiver

extension RemoteObservable: MessageReceiver {

    /**
     Callback to receive messages from the remote component.
     - Parameter message: The message received over the connection
     - Note: This function is called automatically by the connection, and should not be called manually.
     */
    public func didReceive(message: Message) {
        switch message.type {
        case .data:
            didReceive(data: message)
        case .request:
            break
        case .deletionRequest:
            break
        case .subscriptionInclusion, .subscriptionDeletion, .subscriptionExclusion:
            break
        }
    }
}

// MARK: Observable

extension RemoteObservable: Observable {

    /**
     Create a subscription for a receiver
     - Parameter receiver: The receiver of data matching the subscription
     - Returns: The subscription for the receiver
     */
    public func subscribe(_ receiver: any Receiver) -> Subscription {
        let id = nextSubscriptionId()
        let data = RemoteSubscriptionData(id: id, receiver: receiver, manager: self)
        subscriptions[id] = data
        return data.subscription
    }
}

// MARK: Subscription data

/**
 The data required to manage a remote subscription.
 */
private final class RemoteSubscriptionData {

    /// The receiver of the subscription updates
    let receiver: any Receiver

    /// The tree with the inclusion and exclusion rules
    let rules: SubscriptionTree

    /// The provided object to manage the subscription
    let subscription: RemoteSubscription

    /**
     Create subscription data.
     - Parameter id: The id of the subscription
     - Parameter receiver: The receiver of the subscription updates
     - Parameter manager: The object managing the subscription
     */
    init(id: Int, receiver: any Receiver, manager: RemoteObservable) {
        self.receiver = receiver
        self.rules = .init()
        self.subscription = .init(id: id, manager: manager)
    }
}

// MARK: Subscription

/**
 A subscription object used within `RemoteObservable`

 This object is returned to the caller of `subscribe()` on `RemoteObservable` as a generic ``Subscription``.
 The object calls the managing `RemoteObservable` for all actions.

 - Note: Defined in the same file as `RemoteObservable` to access the fileprivate functions
   to manage subscriptions.
 */
final class RemoteSubscription: Subscription {

    /// The unique id of the subscription, passed to subscription management functions
    private let id: Int

    /// The object that manages the subscription, to call subscription management functions
    private let manager: RemoteObservable

    /**
     Create a subscription object for a remote component
     - Parameter id: The id of the subscription
     - Parameter manager: The subscription manager that created the object
     */
    init(id: Int, manager: RemoteObservable) {
        self.id = id
        self.manager = manager
    }

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the inclusion
     */
    @discardableResult
    func include(_ path: Path, depth: Int?) -> Request {
        AsyncRequest {
            await self.manager.include(path, depth: depth, for: self.id).wait()
        }
    }

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the exclusion
     */
    @discardableResult
    func exclude(_ path: Path, depth: Int?) -> Request {
        AsyncRequest {
            await self.manager.exclude(path, depth: depth, for: self.id).wait()
        }
    }

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: A request to wait for completion of the deletion
     */
    @discardableResult
    func deleteRules(at path: Path, depth: Int?) -> Request {
        AsyncRequest {
            await self.manager.deleteRules(at: path, depth: depth, for: self.id).wait()
        }
    }

    /**
     Cancel the subscription.
     - Returns: A request to wait for completion of the cancelation
     */
    @discardableResult
    func cancel() -> Request {
        AsyncRequest {
            await self.manager.cancel(self.id).wait()
        }
    }
}
