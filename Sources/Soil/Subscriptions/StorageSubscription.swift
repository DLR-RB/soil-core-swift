

actor StorageSubscription {

    /**
     The receiver of updates that match the subscription
     */
    private let receiver: any Receiver

    var cancelCallback: (() -> Void)?

    private let root = SubscriptionTree()

    init(receiver: any Receiver, cancel: @escaping @Sendable () -> Void) {
        self.receiver = receiver
        self.cancelCallback = cancel
    }

    /**
     Inform the receiver about new samples
     */
    func receive(_ samples: [Sample], for path: Path) {
        receiver.receive(samples, for: path)
    }

    /**
     Check if a path is covered by the inclusions in the tree.

     The function first finds all existing nodes along the path,
     and then traverses them from the bottom node to the root.
     If a node in the subscription tree has a matching rule
     (based on the relative depth), then the inclusion or exclusion is returned.
     If the full path is traversed to the top, then the path is not included.

     - Parameter path: The path to query subscriptions for
     - Returns: `true`, if the path is included by the subscription.
     */
    func isSubscribed(to path: Path) -> Bool {
        root.isSubscribed(to: path)
    }

    private func includeInternal(_ path: Path, depth: Int?) {
        root.include(path, depth: depth)
    }

    private func excludeInternal(_ path: Path, depth: Int?) {
        root.exclude(path, depth: depth)
    }

    private func deleteRulesInternal(_ path: Path, depth: Int?) {
        root.deleteRules(at: path, depth: depth)
    }

    private func cancelInternal() {
        self.cancelCallback?()
        self.cancelCallback = nil
    }
}

extension StorageSubscription: Subscription {

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the inclusion
     */
    @discardableResult
    nonisolated func include(_ path: Path, depth: Int?) -> Request {
        AsyncRequest {
            await self.includeInternal(path, depth: depth)
        }
    }

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the exclusion
     */
    @discardableResult
    nonisolated func exclude(_ path: Path, depth: Int?) -> Request {
        AsyncRequest {
            await self.excludeInternal(path, depth: depth)
        }
    }

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: A request to wait for completion of the deletion
     */
    @discardableResult
    nonisolated func deleteRules(at path: Path, depth: Int?) -> Request {
        AsyncRequest {
            await self.deleteRulesInternal(path, depth: depth)
        }
    }

    /**
     Cancel the subscription.
     - Returns: A request to wait for completion of the cancelation
     */
    @discardableResult
    nonisolated func cancel() -> Request {
        AsyncRequest {
            await self.cancelInternal()
        }
    }
}