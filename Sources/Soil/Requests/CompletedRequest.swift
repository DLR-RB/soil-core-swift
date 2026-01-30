
/**
 A request that is already completed.
 */
struct CompletedRequest: Request {

    func wait() async { }
}