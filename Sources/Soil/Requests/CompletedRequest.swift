
/**
 A request that is already completed.
 */
public struct CompletedRequest: Request {

    /**
     Immediatelly return since the request is already completed
     */
    public func wait() async { }
}