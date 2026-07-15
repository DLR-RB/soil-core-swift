import Foundation

/**
 A type that can receive messages.
 */
public protocol FrameReceiver: AnyObject, Sendable {

    /**
     Process a received message.

     Each call to this function contains exactly the bytes of one frame.
     - Parameter data: The frame to process
     */
    @discardableResult
    func accept(frame data: Data) -> any Request
}