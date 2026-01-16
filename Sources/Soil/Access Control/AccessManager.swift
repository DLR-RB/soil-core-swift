
/**
 A type that provides access control information for states.
 */
public protocol AccessManager {

    /// The type that is used to identify components for access control
    associatedtype ComponentId: Hashable

    /**
     Indicate if a component is allowed to read a value at a path.
     - Parameter id: The unique id of the component
     - Parameter path: The path attempted to be read by the component
     - Returns: `true`, if the component is allowed to receive the value at the path.
     */
    func component(_ id: ComponentId, canRead path: Path) -> Bool

    /**
     Indicate if a component is allowed to write a value at a path.
     - Parameter id: The unique id of the component
     - Parameter path: The path attempted to be written by the component
     - Returns: `true`, if the component is allowed to set the value at the path.
     */
    func component(_ id: ComponentId, canWrite path: Path) -> Bool
}
