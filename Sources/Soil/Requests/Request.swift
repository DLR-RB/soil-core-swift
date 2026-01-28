
/**
 The summary of a request made to a component.
 */
struct Request {

    /// The unique id used in the request to the component
    let id: Int

    /// The path of the response value
    let path: Path

    /// The type of request made
    let type: RequestType

    /**
     The time when the request was made.

     Can be used to remove requests after a timeout.
     */
    let startTime: Timestamp

    /**
     Create a request
     - Parameter id: The unique id used in the request to the component
     - Parameter path: The path included in the request message
     - Parameter type: The message type, including type-specific information
     - Parameter startTime: The time when the request was made. Defaults to the current time
     */
    init(id: Int, path: Path, type: RequestType, startTime: Timestamp = .current()) {
        self.id = id
        self.path = path
        self.type = type
        self.startTime = startTime
    }
}