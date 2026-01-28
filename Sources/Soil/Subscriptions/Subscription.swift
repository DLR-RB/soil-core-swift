

/**
 A subscription made to a component
 */
public final class Subscription {

    public let id: Int

    private let send: (Message) -> Bool

    private let root = SubscriptionTree()

    /// The closure to call with updates from the component matching the subscription
    public var received: (_ path: Path, _ sample: Sample) -> Void

    init(id: Int, receive: @escaping (_ path: Path, _ sample: Sample) -> Void, send: @escaping (Message) -> Bool) {
        self.id = id
        self.send = send
        self.received = receive
    }

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: `true`, if the inclusion request was sent to the component
     */
    public func include(_ path: Path, depth: Int?) -> Bool {
        let message = Message.include(path, depth: depth, in: id)
        guard send(message) else {
            return false
        }
        root.include(path, depth: depth)
        return true
    }

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: `true`, if the exclusion request was sent to the component
     */
    public func exclude(_ path: Path, depth: Int?) -> Bool {
        let message = Message.exclude(path, depth: depth, from: id)
        guard send(message) else {
            return false
        }
        root.exclude(path, depth: depth)
        return true
    }

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: `true`, if the deletion request was sent to the component
     */
    public func deleteRules(at path: Path, depth: Int?) -> Bool {
        let message = Message.deleteRules(at: path, depth: depth, for: id)
        guard send(message) else {
            return false
        }
        root.deleteRules(at: path, depth: depth)
        return true
    }

    /**
     Delete all rules, effectively canceling the subscription
     - Returns: `true`, if the deletion request was sent to the component
     */
    public func delete() -> Bool {
        deleteRules(at: [], depth: nil)
    }

    // MARK: Update

    /**
     Check if a path is matched by the subscription and send the samples to the callback
     - Parameter samples: The samples to send to subscribers
     - Parameter path: The path associated with the sample
     - Returns: `true`, if the subscription matched an the receive callback was executed with the samples
     */
    @discardableResult
    func process(_ samples: [Sample], at path: Path) -> Bool {
        guard root.isSubscribed(to: path) else {
            return false
        }
        for sample in samples {
            received(path, sample)
        }
        return true
    }

    /**
     Check if a path is matched by the subscription and send the sample to the callback
     - Parameter sample: The sample to send to subscribers
     - Parameter path: The path associated with the sample
     - Returns: `true`, if the subscription matched an the receive callback was executed with the sample
     */
    @discardableResult
    func process(_ sample: Sample, at path: Path) -> Bool {
        process([sample], at: path)
    }
}