
/**
 A component that tracks and responds to subscriptions.

 The name `Observable` was chosen to indicate that changes to the data of the component can be monitored using subscriptions.

 Rejected terms include:
 - Broker: Implies negotiating data transfer
 - Dispatcher: Implies scheduling
 - Notifier: Suggests limited agency of clients, 'notification' suggests only events, not complete data
 - Publisher: Not clear that observers request which data to receive
 */
public protocol Observable: Sendable {

    /**
     Set the receiver for subscription data
     - Parameter receiver: The receiver of data matching the subscription rules
     - Returns: A request to optionally wait for completion
     */
    @discardableResult
    func setReceiver(_ receiver: Receiver?) -> Request

    /**
     Get the receiver for matching data.
     - Returns: The receiver, if set
     */
    func getReceiver() async -> Receiver?

    /**
     Include a path in the subscription.
     - Parameter path: The path to include
     - Parameter depth: The depth of the inclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the inclusion
     */
    @discardableResult
    func include(_ path: Path, depth: Int?) -> Request

    /**
     Exclude a path from the subscription.
     - Parameter path: The path to exclude
     - Parameter depth: The depth of the exclusion (nil indicates the full sub-tree)
     - Returns: A request to wait for completion of the exclusion
     */
    @discardableResult
    func exclude(_ path: Path, depth: Int?) -> Request

    /**
     Delete subscription rules at a path with a given depth
     - Parameter path: The path for which to delete rules
     - Parameter depth: The depth of the deletion
     - Returns: A request to wait for completion of the deletion
     */
    @discardableResult
    func deleteRules(at path: Path, depth: Int?) -> Request

    /**
     Check if a particular path is covered by the current subscription rules.
     - Parameter path: The path to check against the subscription rules
     - Returns: `true`, if the path matches
     */
    func isSubscribed(to path: Path) async -> Bool

    /**
     Use the subscription rules to remove all excluded parts of a tree.
     - Parameter tree: The original tree to strip
     - Parameter path: The path of the tree in relation to the subscription tree
     - Returns: The reduced tree, if any inclusion rules match, otherwise `null`
     */
    func reduce(_ tree: SampleTree, at path: Path) async -> SampleTree?
}

extension Observable {

    /**
     Reduce a tree at a path to contain only the subscribed data.
     */
    func dataForReceiver(tree: SampleTree, path: Path) async -> (tree: any SampleTree, path: Path)? {
        // Filter the data according to the subscription rules
        guard let reduced = await reduce(tree, at: path) else {
            return nil
        }

        // Select only the smallest tree,
        // in case the subscription rules removed some parts
        // that left only a single path at the root
        let (subPath, subTree) = reduced.containedTree()
        return (subTree, path + subPath)
    }

    /**
     Forward the tree and path if it matches the subscription rules.
     - Parameter tree: The tree to distribute
     - Parameter path: The path of the tree
     */
    func distribute(tree: SampleTree, path: Path) async {
        // Get the receiver of the subscription data
        guard let receiver = await getReceiver() else {
            return
        }

        guard let (subscribedTree, subscribedPath) = await dataForReceiver(tree: tree, path: path) else {
            return
        }

        await receiver.receive(subscribedTree, for: subscribedPath).wait()
    }
}
