
/**
 A type that can receive bytes from a binary stream for processing
 */
public protocol StreamReceiver: AnyObject, Sendable {

    /**
     Process received bytes from the stream.

     Each call to this function can contain an arbitrary number of bytes.
     - Parameter bytes: The received bytes to process
     */
    @discardableResult
    func accept(bytes: [UInt8]) -> any Request
}
