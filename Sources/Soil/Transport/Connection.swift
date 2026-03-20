
/**
 * An abstract connection that indicates its status and can be closed
 */
public protocol Connection: Sendable {

    /// Indicate if the connection is open and can receive and transmit data
    func isOpen() async -> Bool

    /**
     * Close the connection
     */
    @discardableResult
    func close() -> Request

    /**
     * Execute a closure when the connection is closed
     * - Parameter block: The closure to execute
     */
    func onClose(perform block: @escaping @Sendable () -> Void) async
}