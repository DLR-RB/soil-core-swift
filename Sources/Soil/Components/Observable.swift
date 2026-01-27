
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
     Create a subscription for future changes to data.
     - Parameter subscription: The subscription id to add
     - Parameter callback: The closure to call with updates in the future.
     - Parameter path: The path of the changed data
     - Parameter sample: The changed data at the path
     - Note: A previous subscription with the same id will be replaced by the new one
     */
    func create(_ subscription: Int, callback: @escaping (_ suscription: Int, _ path: Path, _ sample: Sample) -> Void)

    /**
     Include a path in a subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Parameter subscription: The id of the subscription
     */
    func include(_ path: Path, depth: Int?, in subscription: Int)

    /**
     Exclude a path from a subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Parameter subscription: The id of the subscription
     */
    func exclude(_ path: Path, depth: Int?, from subscription: Int)

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Parameter subscription: The id of the subscription to target.
     */
    func deleteRules(at path: Path, depth: Int?, for subscription: Int)

    /**
     Delete the subscription with the given id.

     Removes the callback and all rules.
     - Parameter subscription: The id of the subscription to delete
     */
    func delete(subscription: Int)

    /**
     Indicate if a callback for the subscription exists.
     - Parameter subscription: The id of the subscription
     - Returns: `true`, if a callback exists.
     */
    func hasSubscription(_ subscription: Int) -> Bool
}

extension Observable {

    /**
     Create a subscription for a path with a callback.
     - Parameter path: The path to subscribe to
     - Parameter callback: The closure to call for new samples
     - Returns: The id of the subscription
     */
    @discardableResult
    func subscribe(to path: Path, callback: @escaping (Sample) -> Void) -> Int {
        let subscription = Int.random()

        create(subscription) { _, _, sample in
            callback(sample)
        }
        include(path, depth: 0, in: subscription)
        return subscription
    }

    /**
     Create a subscription for a path with a callback.
     - Parameter subscription: The id of the subscription
     - Parameter path: The path to subscribe to
     - Parameter callback: The closure to call for new samples
     */
    func subscribe(_ subscription: Int, to path: Path, depth: Int?, callback: @escaping (_ suscription: Int, _ path: Path, _ sample: Sample) -> Void) {
        create(subscription, callback: callback)
        include(path, depth: depth, in: subscription)
    }

    /**
     Delete all existing rules for a subscription without deleting the callback.
     - Parameter subscription: The id of the subscription
     */
    func deleteAllRules(for subscription: Int) {
        deleteRules(at: [], depth: nil, for: subscription)
    }
}