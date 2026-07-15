

/**
 A frame distributor represents a component that transmits frames without being prompted
 */
public protocol FrameDistributor {

    /**
     Set the receiver of the frames
     - Parameter receiver: The receiver of the frames provided by this distributor
     */
    @discardableResult
    func setReceiver(_ receiver: (any FrameReceiver)?) -> any Request

    /**
     Get the current receiver of the frames
     */
    func getReceiver() async -> (any FrameReceiver)?
}
