
/**
 Handles component-internal subscriptions.

 This class allows other types to subscribe to paths with a callback,
 and informs all subscribers about new samples for paths.
 */
final class InternalSubscriptionsManager {

    /// Store the callback functions for each subscriber id
    private var callbacks: [Int : (_ subscriber: Int, _ path: Path, _ sample: Sample) -> Void]

    /// The logic to track subscriptions for paths
    private let manager: SubscriptionManager<Int>

    /**
     Create a new subscription manager.
     */
    init() {
        callbacks = [:]
        manager = .init()
    }

    /**
     Register a callback for a path with an optional depth.

     Only one callback can be registered for a subscriber, even for different paths.
     If a subscriber requires multiple callbacks, then it must use different `id`s.
     Complex subscription patterns using `exclude()` can be created,
     but only the last callback provided to this function is used.

     The `id` can be used to terminate a subscription by calling `remove(subscriber:)`.

     - Parameter id: An id provided by the subscriber to identify it.
     - Parameter path: The path to subscribe to
     - Parameter depth: The number of sub-levels to consider for the subscription
     - Parameter callback: The closure to call when new data is available
     */
    func subscribe(_ subscriber: Int, to path: Path, depth: Int?, callback: @escaping (_ subscriber: Int, _ path: Path, _ sample: Sample) -> Void) {
        // Overrides a potentially existing callback
        callbacks[subscriber] = callback
        // Note: We don't remove a previous subscription, in case the subscriber wants to construct more elaborate calls
        manager.subscribe(subscriber, to: path, depth: depth)
    }

    /**
     Exclude a path from an existing subscription.

     Exclusions only act on subscriptions of the same path or on subscriptions of ancestors.

     If a subscription exists with the same depth for the same path, then the subscription is removed without adding an exclusion.
     Call ``subscribe(_:to:depth:)`` with the same `depth` to remove the exclusion and add a subscription.
     - Parameter subscriber: The id of the subscriber
     - Parameter path: The path to exclude for the subscriber
     - Parameter depth: The optional depth of the exclusion
     */
    func exclude(_ subscriber: Int, from path: Path, depth: Int?) {
        let didAddExclusion = manager.exclude(subscriber, from: path, depth: depth)
        if didAddExclusion {
            // Exclusion added, no subscription removed,
            // so nothing else to do
            return
        }
        // If the exclusion did remove a subscription,
        // then we don't know if the subscriber still has other subscriptions somewhere.
        // We need to check explicitly
        if manager.hasSubscriptions(for: subscriber) {
            // Still some subscriptions present, so nothing more to do.
            return
        }

        // No more subscriptions, so the callback can be removed.
        // The only way to add more subscriptions is to add another callback via subscribe()
        callbacks[subscriber] = nil
    }

    /**
     Remove the callback for an id.
     - Parameter subscriber: The id that was used to call `subscribe(_:path:depth:callback:)`.
     */
    func remove(subscriber: Int) {
        callbacks[subscriber] = nil
        manager.remove(subscriber: subscriber)
    }

    /**
     Inform all subscribers about a new sample for a path via the registered callbacks.
     - Returns: The number of subscribers that were notified about the sample.
     */
    @discardableResult
    func notifySubscribers(about sample: Sample, at path: Path) -> Int {
        var notified = 0
        for subscriber in manager.subscribers(to: path) {
            guard let callback = callbacks[subscriber] else {
                // Attempt to restore a reasonable state by removing the subscriber
                // but this case should not actually be possible
                manager.remove(subscriber: subscriber)
                continue
            }
            callback(subscriber, path, sample)
            notified += 1
        }
        return notified
    }

    // MARK: Testing

    /**
     Check if a callback is registered for a subscriber.
     - Returns: `true`, if a callback is registered
     - Note: This function is only used to test the internal state.
     */
    func hasCallback(for subscriber: Int) -> Bool {
        callbacks[subscriber] != nil
    }

     /**
     Find all subscribers for a given path.
     - Parameter path: The path to query subscribers for
     - Returns: The set of subscribers interested in the path.
     - Note: This function is only used to test the internal state.
     */
    func subscribers(to path: Path) -> Set<Int> {
        manager.subscribers(to: path)
    }

    /**
     Check if there is any subscription registered for the subscriber.
     - Returns: `true`, if one or more subscriptions exist for the id
     */
    func hasSubscriptions(for subscriber: Int) -> Bool {
        manager.hasSubscriptions(for: subscriber)
    }
}