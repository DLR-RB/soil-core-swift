
/**
 Connect to an observable component via a transport layer.
 */
public actor RemoteObservable {

    /// The connection to the remote component via the underlying transport layer
    public let connection: any MessageConnection

    /// The subscription tree with the inclusion and exclusion rules
    private let subscriptions: SubscriptionTree

    /// The receiver of the subscription updates
    private var receiver: (any Receiver)?

    /**
     Create an interface to work with a remote observable component.
     - Parameter connection: The connection to the component
     */
    public init(connection: any MessageConnection) async {
        self.connection = connection
        self.subscriptions = .init()

        // Register to receive messages from the component
        await connection.setReceiver(self)
    }

    // MARK: Transport layer interaction

    /**
     Process a data message, by checking which request it matches
     - Parameter message: The received data message
     */
    private func didReceive(data message: Message) {
        // Note: We know that the message is a data message
        guard let receiver else {
            return
        }

        // Reduce the received tree according to the subscription rules
        guard let reduced = subscriptions.reduce(message.data, for: message.path) else {
            return
        }
        // Note: We don't wait for subscription receiver requests
        receiver.accept(reduced, for: message.path)
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
     Set the receiver for subscription data
     - Parameter receiver: The receiver of data matching the subscription rules
     */
    public nonisolated func setReceiver(_ receiver: Receiver?) -> Request {
        AsyncRequest {
            await self.setReceiverSynchronized(receiver)
        }
    }

    private func setReceiverSynchronized(_ receiver: Receiver?) async {
        self.receiver = receiver
    }

    /**
     Get the receiver for matching data.
     - Returns: The receiver, if set
     */
    public func getReceiver() -> Receiver? {
        return receiver
    }

    /**
     Internal function called by a subscription object to include a path in a subscription.

     If the subscription exists, then a request to include the path will be sent to the remote,
     and the internal subscription state will be updated.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to modify
     - Returns: The request to send the message to the component, or an already completed request.
     */
    public nonisolated func include(_ path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.includeSynchronized(path, depth: depth)
        }
    }

    private func includeSynchronized(_ path: Path, depth: Int?) async {
        // Track the state of the subscription internally,
        // to ensure that updates are properly matched
        subscriptions.include(path, depth: depth)

        await connection.send(message: .include(path, depth: depth)).wait()
    }

    /**
     Internal function called by a subscription object to exclude a path from a subscription.

     If the subscription exists, then a request to exclude the path will be sent to the remote,
     and the internal subscription state will be updated.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to modify
     - Returns: The request to send the message to the component, or an already completed request.
     */
    public nonisolated func exclude(_ path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.excludeSynchronized(path, depth: depth)
        }
    }

    private func excludeSynchronized(_ path: Path, depth: Int?) async {
        // Track the state of the subscription internally,
        // to ensure that updates are properly matched
        subscriptions.exclude(path, depth: depth)

        await connection.send(message: .exclude(path, depth: depth)).wait()
    }

    /**
     Internal function called by a subscription object to delete rules of a subscription.

     If the subscription exists, then a request to remove the rules will be sent to the remote,
     and the internal subscription state will be updated.
     If no subscription exists (or was already canceled), then the function does nothing.
     - Parameter id: The id of the subscription to modify
     - Returns: The request to send the message to the component, or an already completed request.
     */
    public nonisolated func deleteRules(at path: Path, depth: Int?) -> any Request {
        AsyncRequest {
            await self.deleteRulesSynchronized(path: path, depth: depth)
        }
    }

    private func deleteRulesSynchronized(path: Path, depth: Int?) async {
        // Track the state of the subscription internally,
        // to ensure that updates are properly matched
        subscriptions.deleteRules(at: path, depth: depth)

        await connection.send(message: .deleteRules(at: path, depth: depth)).wait()
    }


    /**
     Check if a particular path is covered by the current subscription rules.
     - Parameter path: The path to check against the subscription rules
     - Returns: `true`, if the path matches
     */
    public func isSubscribed(to path: Path) -> Bool {
        subscriptions.isSubscribed(to: path)
    }

    /**
     Use the subscription rules to remove all excluded parts of a tree.
     - Parameter tree: The original tree to strip
     - Parameter path: The path of the tree in relation to the subscription tree
     - Returns: The reduced tree, if any inclusion rules match, otherwise `null`
     */
    public func reduce(_ tree: SampleTree, at path: Path) -> SampleTree? {
        subscriptions.reduce(tree, for: path)
    }
}
