
/// A SOIL path component (a string), to construct paths
public typealias PathComponent = String

/// A SOIL path (an array of strings) identifying a state, input or output
public typealias Path = [PathComponent]

extension Path {

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

    func removing(prefix: Path) -> Path {
        // A prefix can only match if the path is at least as long as the prefix
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
