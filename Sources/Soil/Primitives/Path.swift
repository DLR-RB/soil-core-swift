
/// A SOIL path component (a string), to construct paths
public typealias PathComponent = String

/// A SOIL path (an array of strings) identifying a state, input or output
public typealias Path = [PathComponent]

extension Path {

    /**
     Check if the path starts with another path.
     - Parameter prefix: The path to check as the prefix
     - Returns: `true`, if this path starts with the prefix path
     */
    func hasPrefix(_ prefix: Path) -> Bool {
        // A prefix can only match if the path is at least as the prefix
        guard self.count >= prefix.count else { return false }
        for index in 0..<prefix.count {
            if self[index] != prefix[index] {
                return false
            }
        }
        return true
    }

    /**
     Remove a prefix from the path.
     - Note: If the path does not start with the prefix, then it remains unchanged.
     - Parameter prefix: The path to remove as the prefix
     - Returns: The path without the given prefix.
     */
    func removing(prefix: Path) -> Path {
        guard hasPrefix(prefix) else {
            return self
        }
        return Array(self[prefix.count...])
    }
}

extension Path: @retroactive Comparable {

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
    public static func < (lhs: [Element], rhs: [Element]) -> Bool {
        let minCount = Swift.min(lhs.count, rhs.count)
        for i in 0..<minCount {
            if lhs[i] < rhs[i] { return true }
            if lhs[i] > rhs[i] { return false }
        }
        return lhs.count < rhs.count
    }
}
