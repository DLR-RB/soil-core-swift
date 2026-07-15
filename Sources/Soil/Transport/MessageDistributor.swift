

/**
 A message distributor represents a component that transmits messages without being prompted
 */
public protocol MessageDistributor {

    /**
     Set the receiver of the messages
     - Parameter receiver: The receiver of the messages provided by this distributor
     */
    @discardableResult
    func setReceiver(_ receiver: (any MessageReceiver)?) -> any Request

    /**
     Get the current receiver of the messages
     */
    func getReceiver() async -> (any MessageReceiver)?
}