import Foundation

/// The timestamp of a value
public typealias Timestamp = Date

extension Timestamp {

    /// The current time
    public static func current() -> Timestamp {
        Date()
    }
}