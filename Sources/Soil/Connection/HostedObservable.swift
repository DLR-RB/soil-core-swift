
/**
 Provides access to an observable through a transport interface.
 */
public actor HostedObservable {

    /// The observed component that is exposed
    private let observable: any Observable

    /// The connection over which the observable is exposed
    public let connection: any MessageConnection

    /**
     Create hosting for an observable over a connection.
     - Parameter observable: The component to expose
     - Parameter connection: The connection to use for hosting
     */
    public init(hosting observable: any Observable, through connection: any MessageConnection) async {
        self.observable = observable
        self.connection = connection

        // Register to receive messages from the component
        await connection.setReceiver(self).wait()
        await observable.setReceiver(self).wait()
    }

    // MARK: Subscription message handling

    /**
     Process subscription messages received over the connection
     - Parmaeter request: The received subscription request message
     */
    private func didReceive(subscriptionRequest request: Message) async {
        switch request.type {
            case .subscriptionInclusion:
                observable.include(request.path, depth: request.depth)
            case .subscriptionDeletion:
                observable.exclude(request.path, depth: request.depth)
            case.subscriptionExclusion:
                observable.deleteRules(at: request.path, depth: request.depth)
            default:
                break // Non-subscription requests handled elsewhere
        }
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
    public nonisolated func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        connection.accept(tree, for: path)
    }
}
