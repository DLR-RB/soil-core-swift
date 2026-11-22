

/// A value with a timestamp
public struct Sample: Sendable {

    /// The value associated with the timestamp
    public let value: Value

    /// The timestamp of the value
    public let timestamp: Timestamp?

    /**
     Create a sample.
     - Parameter value: The contained value
     - Parameter date: The timestamp associated with the value.
     */
    public init(value: Value, timestamp: Timestamp? = nil) {
        self.value = value
        self.timestamp = timestamp
    }

    /**
     Create a sample, after converting a value to a SOIL value.
     - Parameter value: The contained value
     - Parameter timestamp: The timestamp associated with the value.
     - Throws: An error, if the value can't be converted to a SOIL value
     */
    // Disfavored, so that literals use the non-throwing `Value` overload
    @_disfavoredOverload
    public init(value: some ValueConvertible, timestamp: Timestamp? = nil) throws {
        self.init(value: try value.soilValue, timestamp: timestamp)
    }

    /**
     Convert the value of the sample to a specific type.
     - Parameter type: The type to convert the value to
     - Returns: The converted value, or `nil`, if the value can't be converted
     */
    public func value<T: ValueConvertible>(as type: T.Type = T.self) -> T? {
        T(soilValue: value)
    }

    /// The timestamp of the sample, or the current time
    public var time: Timestamp {
        timestamp ?? .current()
    }

    /**
     Create a timestamped value with a unix timestamp (seconds since 1970).
     - Parameter value: The contained value
     - Parameter timestamp: The unix timestamp associated with the value.
     */
    public init(value: Value, timeIntervalSince1970: Double) {
        self.init(value: value, timestamp: .init(timeIntervalSince1970: timeIntervalSince1970))
    }

    /**
     Set the timestamp to the current time, if it is not set already.
     */
    public func withTimeSet() -> Sample {
        if timestamp != nil {
            return self
        }
        return .init(value: value, timestamp: .current())
    }
}

extension Sample: Equatable {

}

extension Sample: Comparable {

    public static func < (lhs: Sample, rhs: Sample) -> Bool {
        guard let lhsTime = lhs.timestamp else {
            // `nil` represents end of time, so lhs can't be smaller than rhs
            return false
        }
        guard let rhsTime = rhs.timestamp else {
            return true // rhs is end of time, so lhs must be smaller
        }
        // Compare finite values
        return lhsTime < rhsTime
    }
}

extension Sample: CustomStringConvertible {

    private var timeString: String? {
        timestamp?.formatted(date: .numeric, time: .standard)
    }

    public var description: String {
        "\(value) (\(timeString ?? "now"))"
    }
}
