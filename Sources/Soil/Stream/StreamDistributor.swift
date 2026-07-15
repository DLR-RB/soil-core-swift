

/**
 A stream distributor represents a component that transmits stream data without being prompted
 */
public protocol StreamDistributor {

    /**
     Set the receiver of the stream data
     - Parameter receiver: The receiver of the stream data provided by this distributor
     */
    @discardableResult
    func setReceiver(_ receiver: (any StreamReceiver)?) -> any Request

    /**
     Get the current receiver of the stream data
     */
    func getReceiver() async -> (any StreamReceiver)?
}
