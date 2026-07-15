

/**
 A distributor represents a component that transmits data without being prompted

 The name "distributor" was choosen to emphasize that the component is sending data
 that is not necessarily requested (in contrast to a `provider` or an `observable`).
 A `distributor` is not necessarily the source of the data it sends.
 Rejected terms:
 - (data) source: Not necessarily creator of data, could be a relay.
 - producer: Not necessarily creator of data, could be a relay.
 - publisher: Does not necessarily handle subscriptions.
 - dispatcher: suggests complex logic
 - notifier: suggests subscriptions
 - feed: implies continuity
 - transmitter: closest alternative name
 */
public protocol Distributor {

    /**
     Set the receiver of the data
     - Parameter receiver: The receiver of the data provided by this distributor
     */
    @discardableResult
    func setReceiver(_ receiver: (any Receiver)?) -> any Request

    /**
     Get the current receiver of the data
     */
    func getReceiver() async -> (any Receiver)?
}
