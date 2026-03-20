
/**
 * An object that can convert a path into a string for display
 */
public protocol PathFormatter: Sendable {

    /**
     Convert a path to a string
     - Parameter path: The path to convert
     - Returns: The string representation of the path
     */
    func string(from path: Path) -> String
}