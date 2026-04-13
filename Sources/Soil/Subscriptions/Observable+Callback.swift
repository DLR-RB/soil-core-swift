
extension Observable {

    /**
     Subscribe a single callback to an observable.
     - Parameter path: The path to observe
     - Parameter depth: The depth of the subscription, defaults to `0`
     - Parameter callback: The closure to call with new samples.
     - Returns: The created subscription, to modify with more rules
     */
    @discardableResult
    public func subscribe(to path: Path, depth: Int? = 0, callback: @escaping @Sendable (_ samples: any SampleTree, _ path: Path) async -> Void) async -> Subscription {
        let receiver = CallbackReceiver(callback: callback)
        let subscription = await subscribe(receiver)
        subscription.include(path, depth: depth)
        return subscription
    }
}
