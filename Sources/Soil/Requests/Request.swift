
/**
 The summary of a request made to a component
 */
struct Request<ComponentId> {

    /**
     The id of the component from which the response was received
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

    init(component: ComponentId, id: Int, path: Path, type: RequestType) {
        self.component = component
        self.id = id
        self.path = path
        self.type = type
        self.startTime = .current()
    }
}