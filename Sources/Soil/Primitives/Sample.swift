

/// A value with a timestamp
public struct Sample {

    /// The value associated with the timestamp
    public let value: Value

    /// The timestamp of the value
    public let timestamp: Timestamp

    /**
     Create a sample.
     - Parameter value: The contained value
     - Parameter date: The timestamp associated with the value.
     */
    public init(value: Value, timestamp: Timestamp = .current()) {
        self.value = value
        self.timestamp = timestamp
    }

    /**
     Create a timestamped value with a unix timestamp (seconds since 1970).
     - Parameter value: The contained value
     - Parameter timestamp: The unix timestamp associated with the value.
     */
    public init(value: Value, timeIntervalSince1970: Double) {
        self.init(value: value, timestamp: .init(timeIntervalSince1970: timeIntervalSince1970))
    }
}

extension Sample: Equatable {

}

extension Sample: Comparable {

    public static func < (_ lhs: Sample, _ rhs: Sample) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}

extension Sample: Codable {

    enum CodingKeys: Int, CodingKey {
        case value = 0
        case timestamp = 1
    }
}

extension Sample: CustomStringConvertible {

    public var description: String {
        "\(value) (\(timestamp.formatted(date: .numeric, time: .standard)))"
    }
}
