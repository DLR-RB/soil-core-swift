
/**
 A request that is already completed.
 */
public struct CompletedRequest: Request {

    /**
     Create a request that is already completed.
     */
    public init() { }

    /**
     Immediatelly return since the request is already completed
     */
    public func wait() async { }
}