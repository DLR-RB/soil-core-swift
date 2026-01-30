
/**
 A component that tracks and responds to subscriptions.

 The name `Observable` was chosen to indicate that changes to the data of the component can be monitored using subscriptions.

 Rejected terms include:
 - Broker: Implies negotiating data transfer
 - Dispatcher: Implies scheduling
 - Notifier: Suggests limited agency of clients, 'notification' suggests only events, not complete data
 - Publisher: Not clear that observers request which data to receive
 */
public protocol Observable {

    /**
     Create a subscription for a receiver
     - Parameter receiver: The receiver of data matching the subscription
     - Returns: The subscription for the receiver
     */
    func subscribe(_ receiver: any Receiver) async -> Subscription
}
