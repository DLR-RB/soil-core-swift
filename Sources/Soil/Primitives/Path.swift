/// A SOIL path component (a string), to construct paths
public typealias PathComponent = String

/**
 A SOIL path (a sequence of strings) identifying a state, input or output.

 Paths behave like arrays of components, and can be created from array literals:

 ```swift
 let path: Path = ["room", "light"]
 let child = path + ["brightness"]
 ```

 Since `Path` is a distinct type, it is converted to a `.path` value,
 while `[String]` is converted to a `.list` value.
 */
public struct Path: Sendable, Hashable {

    /// The components of the path
    public var components: [PathComponent]

    /// Create a path from components
    public init(_ components: [PathComponent]) {
        self.components = components
    }

    /// Create a path from a sequence of components
    public init<S: Sequence>(_ components: S) where S.Element == PathComponent {
        self.components = Array(components)
    }
}

extension Path: ExpressibleByArrayLiteral {

    /// Create a path from an array literal of components
    public init(arrayLiteral elements: PathComponent...) {
        self.components = elements
    }
}

extension Path: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {

    public typealias SubSequence = ArraySlice<PathComponent>

    public init() {
        self.components = []
    }

    public var startIndex: Int { components.startIndex }

    public var endIndex: Int { components.endIndex }

    public subscript(position: Int) -> PathComponent {
        get { components[position] }
        set { components[position] = newValue }
    }

    public subscript(bounds: Range<Int>) -> ArraySlice<PathComponent> {
        get { components[bounds] }
        set { components[bounds] = newValue }
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C) where C.Element == PathComponent {
        components.replaceSubrange(subrange, with: newElements)
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        components.reserveCapacity(minimumCapacity)
    }
}

extension Path {

    /**
     Check if the path starts with another path.
     - Parameter prefix: The path to check as the prefix
     - Returns: `true`, if this path starts with the prefix path
     */
    public func hasPrefix(_ prefix: Path) -> Bool {
        starts(with: prefix)
    }

    /**
     Remove a prefix from the path.
     - Note: If the path does not start with the prefix, then it remains unchanged.
     - Parameter prefix: The path to remove as the prefix
     - Returns: The path without the given prefix.
     */
    public func removing(prefix: Path) -> Path {
        guard hasPrefix(prefix) else {
            return self
        }
        return Path(self[prefix.count...])
    }

    /**
     Determine the maximum prefix that the path shares with another path
     - Parameter other: The second path to determine the common prefix
     - Returns: The prefix matching both paths
     */
    public func commonPrefix(with other: Path) -> Path {
        let maxIndex = Swift.min(other.count, count)
        var common: Path = []
        for index in 0..<maxIndex {
            if self[index] != other[index] {
                break
            }
            common.append(self[index])
        }
        return common
    }

    /**
     Compute the prefix of the path in common with a given path,
     and return the remaining relative paths.
     - Parameter other: The second path to determine the common prefix
     - Returns: The prefix matching both paths, and the remaining subpaths
     */
    public func extractCommonPrefix(with other: Path) -> (prefix: Path, remainder: Path, otherRemainer: Path) {
        let prefix = commonPrefix(with: other)
        let remainder = Path(dropFirst(prefix.count))
        let otherRemainder = Path(other.dropFirst(prefix.count))
        return (prefix, remainder, otherRemainder)
    }
}

extension Path: Comparable {

    /**
     Sort paths by comparing their components.

     Paths are sorted by their components starting from the beginning of the path,
     and shorter paths are sorted before longer paths.

     ```
     ["a", "b"] < ["b"] // true
     ["a", "b"] < ["a", "c"] // true
     ["a", "b"] < ["a", "b", "c"] // true
     ```
     */
    public static func < (lhs: Path, rhs: Path) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

extension Path: CustomStringConvertible {

    /// The components of the path, separated by `/`
    public var description: String {
        "/" + components.joined(separator: "/")
    }
}

extension Path: Codable {

    /// Decode a path from an array of strings
    public init(from decoder: any Decoder) throws {
        self.components = try [PathComponent](from: decoder)
    }

    /// Encode a path as an array of strings
    public func encode(to encoder: any Encoder) throws {
        try components.encode(to: encoder)
    }
}
