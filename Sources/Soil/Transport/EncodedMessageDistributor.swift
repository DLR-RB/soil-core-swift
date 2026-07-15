

/**
 An encoded message distributor represents a component that transmits encoded messages without being prompted
 */
public protocol EncodedMessageDistributor {

    /**
     Set the receiver of the encoded messages
     - Parameter receiver: The receiver of the encoded messages provided by this distributor
     */
    @discardableResult
    func setReceiver(_ receiver: (any EncodedMessageReceiver)?) -> any Request

    /**
     Get the current receiver of the encoded messages
     */
    func getReceiver() async -> (any EncodedMessageReceiver)?
}
