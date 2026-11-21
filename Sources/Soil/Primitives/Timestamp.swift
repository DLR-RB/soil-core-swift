import Foundation

/// The timestamp of a value
public typealias Timestamp = Date

extension Timestamp {

    /// The current time
    public static func current() -> Timestamp {
        Date()
    }
}

extension Optional where Wrapped == Timestamp {

    /**
     Compare two optional timestamps, allowing for a small difference.
     - Parameter other: The timestamp to compare to
     - Parameter tolerance: The maximum allowed difference between the timestamps (in seconds)
     - Returns: `true`, if both timestamps are `nil`, or if both are set and within the tolerance
     */
    func isEqual(to other: Timestamp?, tolerance: TimeInterval) -> Bool {
        guard let self else {
            return other == nil
        }
        guard let other else {
            return false
        }
        return abs(self.distance(to: other)) <= tolerance
    }
}
