
/**
 The summary of a request made to a component.

 A request is generic over the component id, which is determined by the transport layer.
 */
struct Request<ComponentId> {

    /**
     The id of the component to which the request is made
     */
    let component: ComponentId

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
     - Parameter component: The id of the component to which the request is made
     - Parameter id: The unique id used in the request to the component
     - Parameter path: The path included in the request message
     - Parameter type: The message type, including type-specific information
     - Parameter startTime: The time when the request was made. Defaults to the current time
     */
    init(component: ComponentId, id: Int, path: Path, type: RequestType, startTime: Timestamp = .current()) {
        self.component = component
        self.id = id
        self.path = path
        self.type = type
        self.startTime = startTime
    }
}