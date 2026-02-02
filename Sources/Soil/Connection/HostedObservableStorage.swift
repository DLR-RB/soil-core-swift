
/**
 Expose an observable storage over an interface.

 It internally creates a ``HostedObservable`` and ``HostedStorage``,
 and distributes messages from the component to both objects.
 */
public actor HostedObservableStorage {

    /// The exposed observable managing the subscriptions
    private let observable: HostedObservable

    /// The exposed storage
    private let storage: HostedStorage

    /**
     Host an observable storage over a connection.
     - Parameter observable: The observable storage to expose.
     - Parameter connection: The connection over which to expose the observable storage
     */
    public init(host observable: any Observable & Storage, through connection: any MessageConnection) async {
        // Note: Currently incoming data will be echoed back if the remote subscribes to the path
        // This could lead to infinite loops
        self.observable = await .init(hosting: observable, through: connection)
        self.storage = await .init(hosting: observable, through: connection)

        // Receive messages in this class, and redistribute to the parts
        await connection.setReceiver(self)
    }
}

extension HostedObservableStorage: MessageReceiver {

    /**
     Insertion point for messages received over the connection.

     Subscription messages are forwarded to the contained observable,
     while data, requests, and deletions are forwarded to the wrapped storage.
     - Parameter message: The message received over the connection.
     - Note: This function is called automatically be the connection, and should not be called manually.
     */
    public func didReceive(message: Message) async {
        switch message.type {
        case .data, .request, .deletionRequest:
            await storage.didReceive(message: message)
        case .subscriptionInclusion, .subscriptionExclusion, .subscriptionDeletion:
            await observable.didReceive(message: message)
        }
    }
}