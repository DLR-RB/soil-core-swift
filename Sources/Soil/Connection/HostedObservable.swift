
/**
 Provides access to an observable through a transport interface.
 */
public actor HostedObservable {

    /// The observed component that is exposed
    private let observable: any Observable

    /// The connection over which the observable is exposed
    private let connection: any MessageConnection

    /// The subscriptions of the connecting component
    private var subscriptions: [Int : Subscription] = [:]

    /**
     Create hosting for an observable over a connection.
     - Parameter observable: The component to expose
     - Parameter connection: The connection to use for hosting
     */
    public init(hosting observable: any Observable, through connection: any MessageConnection) async {
        self.observable = observable
        self.connection = connection

        // Register to receive messages from the component
        await connection.setReceiver(self)
    }

    // MARK: Subscription message handling

    /**
     Process subscription messages received over the connection
     - Parmaeter request: The received subscription request message
     */
    private func didReceive(subscriptionRequest request: Message) async {
        let subscription = await subscription(id: request.id ?? 0)
        switch request.type {
            case .subscriptionInclusion:
                subscription.include(request.path, depth: request.depth)
            case .subscriptionDeletion:
                subscription.exclude(request.path, depth: request.depth)
            case.subscriptionExclusion:
                subscription.deleteRules(at: request.path, depth: request.depth)
            default:
                break // Non-subscription requests handled elsewhere
        }
    }

    /**
     Get or create a subscription object for a subscription id.
     - Parameter id: The id of the subscription
     - Returns: An existing or new subscription for the id
     */
    private func subscription(id: Int) async -> Subscription {
        if let subscription = subscriptions[id] {
            return subscription
        }
        let created = await observable.subscribe(self)
        subscriptions[id] = created
        return created
    }

    /// The number of subscriptions currently registered by the component
    public var numberOfSubscriptions: Int {
        subscriptions.count
    }
}

// MARK: Message receiver

extension HostedObservable: MessageReceiver {

        /**
     Insertion point for messages received over the connection.

     Only subscription messages are considered when hosting observable components.
     - Parameter message: The message received over the connection.
     - Note: This function is called automatically be the connection, and should not be called manually.
     */
    public func didReceive(message: Message) async {
        switch message.type {
        case .data, .request, .deletionRequest:
            return
        case .subscriptionInclusion, .subscriptionDeletion, .subscriptionExclusion:
            await didReceive(subscriptionRequest: message)
        }
    }
}

// MARK: Receiver

extension HostedObservable: Receiver {

    /**
     Receive updates matching the subscriptions from the wrapped observable to send over the connection.
     - Note: This function is called automatically be the wrapped observable.
       It should not be called manually.
     */
    public nonisolated func receive(_ samples: [Sample], for path: Path) -> any Request {
        connection.receive(samples, for: path)
    }
}