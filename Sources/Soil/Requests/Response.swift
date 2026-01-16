
/**
 A response from a component to a request from a client.
 */
struct Response<ComponentId> {

    /// The request associated with this response
    let request: Request<ComponentId>

    /// The path contained in the response
    let path: Path

    /// The value at the path
    let value: Value?

    /// The timestamp of the value
    let timestamp: Timestamp?

    /// The samples contained in the response message
    let samples: [Sample]

    /**
    Indicates if the response completed the request.

    If the value is `nil`, then the component did not include completeness information
    */
    let isCompleted: Bool?
}