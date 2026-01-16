
/**
 A type-erased wrapper for access managers to be used in `Client`
 without having to make `Client` generic over `AccessManager`.
 */
struct AnyAccessManager<ComponentId: Hashable>: AccessManager {

    private let canRead: (ComponentId, Path) -> Bool

    private let canWrite: (ComponentId, Path) -> Bool

    init<A: AccessManager>(_ manager: A) where A.ComponentId == ComponentId {
        self.canRead = manager.component(_:canRead:)
        self.canWrite = manager.component(_:canWrite:)
    }

    /**
     Indicate if a component is allowed to read a value at a path.
     - Parameter id: The unique id of the component
     - Parameter path: The path attempted to be read by the component
     - Returns: `true`, if the component is allowed to receive the value at the path.
     */
    func component(_ id: ComponentId, canRead path: Path) -> Bool {
        canRead(id, path)
    }

    /**
     Indicate if a component is allowed to write a value at a path.
     - Parameter id: The unique id of the component
     - Parameter path: The path attempted to be written by the component
     - Returns: `true`, if the component is allowed to set the value at the path.
     */
    func component(_ id: ComponentId, canWrite path: Path) -> Bool {
        canWrite(id, path)
    }
}
