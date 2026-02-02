
/**
 A request describes an ongoing operation,
 which can be waited for.

 Requests are used to query data from receivers, to establish subscriptions, or schedule data deletion.
 */
public protocol Request: Sendable {

    /**
     Wait for the request to complete.

     The request will be performed in the background even if wait is not called.
     If the request is already completed, then wait will return immediatelly.
     */
    func wait() async
}