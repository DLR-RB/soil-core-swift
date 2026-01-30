
/**
 A request describes an ongoing operation,
 which can be waited for.

 Requests are used to query data from receivers, to establish subscriptions, or schedule data deletion.
 */
public protocol Request {

    func wait() async
}