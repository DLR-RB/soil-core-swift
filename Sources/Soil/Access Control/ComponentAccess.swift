
/**
 A type that provides access control information for states.
 */
public protocol ComponentAccess {

    /**
     Indicate if a component is allowed to read a value at a path.
     - Parameter path: The path attempted to be read by the component
     - Returns: `true`, if the component is allowed to receive the value at the path.
     */
    func component(canRead path: Path) -> Bool

    /**
     Indicate if a component is allowed to write a value at a path.
     - Parameter path: The path attempted to be written by the component
     - Returns: `true`, if the component is allowed to set the value at the path.
     */
    func component(canWrite path: Path) -> Bool

    /**
     Indicate if a component is allowed to delete values at a path.
     - Parameter path: The path attempted to be deleted by the component
     - Returns: `true`, if the component is allowed to delete values at the path.
     */
    func component(canDelete path: Path) -> Bool
}
