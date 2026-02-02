
/**
 A message to transmit between components.

 This structure implements all three message types (see ``MessageType``) in a single message through optional properties.
 */
public struct Message: Sendable {

    /// Indicate the message type (may be ommited for a data message)
    public let type: MessageType

    /**
     The identifying path of the data contained at the top level of this message

     Usage:
     - Data message: The path associated with the sample(s)
     - Request message: The requested path
     - Subscription inclusion: The path to include
     - Subscription exclusion: The path to exclude
     - Subscription deletion: The path for which to delete subscription rules
     */
    public let path: Path

    /**
     A value associated with the `path`.

     Usage:
     - Data message: The single value transmitted for a path

     - Note: If `time` is set, then it represents the timestamp of the value,
       otherwise the value is treated as a current time value.
     */
    public let value: Value?

    /**
     The samples associated with the `path`.
     Can be ommitted from messages if empty.

     Usage:
     - Data message: Used to transmit multiple samples for a path
     */
    public let samples: [Sample]

    /**
     A generic count or limit

     Usage:
     - Data message: Indicate the total number of messages for the request (if request id is set)
     - Request message: The maximum number of samples to return
     */
    public let count: Int?

    /**
     The depth of a tree.

     Usage:
     - Request message: Indicate the maximum depth (Negative values are treated as 0)
     - Subscription inclusion: The depth of the inclusion at the path
     - Subscription exclusion: The depth of the exclusion at the path
     */
    public let depth: Int?

    /**
     A (start) date.

     Usage:
     - Data message: Used together with `value` to indicate the timestamp (`nil` represents the current time).
     - Request message: Used as the `start` date for the requested path.
     */
    public let time: Timestamp?

    /**
     The end date used in requests.

     Usage:
     - Request message: Used to indicate the end of a request interval.
     */
    public let end: Timestamp?

    /**
     The id of the request or subscription.

     Usage:
     - Data message: Identifies the request that this value corresponds to.
     - Request message: An identifier to include in responses to the request.
     - Subscription message: The unique id of the subscription.
     */
    public let id: Int?

    /**
     Create a message.
     - Parameter type: The message type
     - Parameter path: The path associated with the data or request
     - Parameter value: The single value in a data message
     - Parameter time: The value timestamp or start date
     - Parameter samples: The samples in a data message
     - Parameter count: The limit in requests or message count in responses
     - Parameter depth: The subscription depth
     - Parameter end: The end date in history requests
     - Parameter id: The request or subscription id
     */
    init(
        type: MessageType,
        path: Path,
        value: Value? = nil,
        time: Timestamp? = nil,
        samples: [Sample] = [],
        count: Int? = nil,
        depth: Int? = nil,
        end: Timestamp? = nil,
        id: Int? = nil
    ) {
        self.type = type
        self.path = path
        self.value = value
        self.samples = samples
        self.count = count
        self.depth = depth
        self.time = time
        self.end = end
        self.id = id
    }

    /// The sample in the message containing the value
    var sample: Sample? {
        guard let value else {
            return nil
        }
        return .init(value: value, timestamp: time ?? .current())
    }

    /// Indicate if the message contains any samples
    var hasSamples: Bool {
        value != nil || !samples.isEmpty
    }

    /// All samples contained in the message (not necessarily sorted)
    var allSamples: [Sample] {
        guard let sample else {
            return samples
        }
        // Note: Not sorted
        return [sample] + samples
    }
}

extension Message {

    /**
     Create an empty message to acknowledge a subscription/exclusion or history request.
     - Parameter path: The path of the original request.
     - Parameter request: The id of the original request.
     - Parameter timestamp: An optional timestamp to signal the processing time of the request.
     - Note: The message type will be set to `data`
     */
    public static func acknowledge(_ request: Int, to path: Path, timestamp: Timestamp? = nil) -> Self {
        .init(
            type: .data,
            path: path,
            time: timestamp,
            id: request)
    }

    // MARK: Data

    /**
     Create a push message to transmit a value.
     - Parameter path: The path of the value to transmit.
     - Parameter value: The value associated with the path.
     - Parameter timestamp: The timestamp associated with the value. `nil` indicates current time.
     - Parameter request: The optional request id, if this is a response, or if an acknowledgement is expected.
     - Parameter totalMessages: The total number of messages in response to the request
     - Note: The message type will be set to `data`
     */
    public static func value(_ value: Value, for path: Path, at timestamp: Timestamp? = nil, inResponseTo request: Int? = nil, withCount totalMessages: Int? = nil) -> Self {
        .init(
            type: .data,
            path: path,
            value: value,
            time: timestamp,
            count: totalMessages,
            id: request)
    }

    /**
     Create a message with several samples.
     - Parameter path: The path of the value to transmit.
     - Parameter samples: The samples associated with the path.
     - Parameter request: The optional id of the request that prompted the message.
     - Parameter totalMessages: The total number of messages in response to the request
     - Note: The message type will be set to `data`
     */
    public static func samples(_ samples: [Sample], for path: Path, inResponseTo request: Int? = nil, totalMessages: Int? = nil) -> Self {
        .init(
            type: .data,
            path: path,
            samples: samples,
            count: totalMessages,
            id: request)
    }

    // MARK: Requests

    /**
     Create a message for a history request.
     - Parameter path: The path for which history is requested.
     - Parameter start: The start date of the requested interval (exclusive). `nil` indicates beginning of time.
     - Parameter end: The end date of the requested interval (inclusive). `nil` indicates end of time.
     - Parameter limit: The maximum number of samples to send, counting from `start`
     - Parameter depth: The number of levels below the path to include.
     - Parameter id: The optional request id to include in responses.
     - Note: The message type will be set to `request`
     */
    public static func request(_ path: Path, from start: Timestamp? = nil, to end: Timestamp? = nil, limit: Int? = nil, depth: Int? = nil, id: Int? = nil) -> Self {
        .init(
            type: .request,
            path: path,
            time: start,
            count: limit,
            depth: depth,
            end: end,
            id: id)
    }

    /**
     Create a message for a deletion request.
     - Parameter path: The path for which the deletion is requested.
     - Parameter start: The start date of the interval to delete (exclusive). `nil` indicates beginning of time.
     - Parameter end: The end date of the interval to delete (inclusive). `nil` indicates end of time.
     - Parameter depth: The number of levels below the path to delete.
     - Parameter id: The optional request id to request a response.
     - Note: The message type will be set to `deletionRequest`
     */
    public static func delete(_ path: Path, from start: Timestamp? = nil, to end: Timestamp? = nil, depth: Int? = nil, id: Int? = nil) -> Self {
        .init(
            type: .deletionRequest,
            path: path,
            time: start,
            depth: depth,
            end: end,
            id: id)
    }

    // MARK: Subscription operations

    /**
     Create a subscription request.
     - Parameter path: The path to subscribe to.
     - Parameter depth: The number of levels below the path to subscribe to.
     - Parameter subscription: The id of the subscription.
     - Note: The message type will be set to `subscriptionInclusion`
     */
    public static func include(_ path: Path, depth: Int? = nil, in subscription: Int) -> Self {
        subscriptionRequest(.subscriptionInclusion, on: subscription, for: path, with: depth)
    }

    /**
     Create a request for an exclusion from a subscription.
     - Parameter path: The path to exclude.
     - Parameter depth: The number of levels below the path to exclude.
     - Parameter subscription: The id of the subscription.
     - Note: The message type will be set to `subscriptionExclusion`
     */
    public static func exclude(_ path: Path, depth: Int? = nil, from subscription: Int) -> Self {
        subscriptionRequest(.subscriptionExclusion, on: subscription, for: path, with: depth)
    }

    /**
     Create a request to delete a subscription.
     - Parameter path: The path for which to delete subscription rules
     - Parameter subscription: The id of the subscription to delete
     - Note: The message type will be set to `subscriptionDeletion`
     */
    public static func deleteRules(at path: Path, depth: Int? = nil, for subscription: Int) -> Self {
        subscriptionRequest(.subscriptionDeletion, on: subscription, for: path, with: depth)
    }

    /**
     Create a request for a subscription inclusion, exclusion or deletion.
     - Parameter type: The message type to set
     - Parameter path: The path to include, exclud, or delete.
     - Parameter depth: The number of levels below the path to include/exclude/delete.
     - Parameter subscription: The id of the subscription to modify
     */
    public static func subscriptionRequest(_ type: MessageType, on subscription: Int, for path: Path, with depth: Int? = nil) -> Self {
        .init(
            type: type,
            path: path,
            depth: depth,
            id: subscription)
    }
}

// MARK: Encoding

extension Message: Codable {

    enum CodingKeys: Int, CodingKey {
        case type = 0
        case path = 1
        case value = 2
        case samples = 3
        case count = 4
        case depth = 5
        case time = 6
        case end = 7
        case id = 8
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(MessageType.self, forKey: .type) ?? .data
        self.path = try container.decodeIfPresent(Path.self, forKey: .path) ?? []
        self.value = try container.decodeIfPresent(Value.self, forKey: .value)
        self.samples = try container.decodeIfPresent([Sample].self, forKey: .samples) ?? []
        self.count = try container.decodeIfPresent(Int.self, forKey: .count)
        self.depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        self.time = try container.decodeIfPresent(Double.self, forKey: .time).map { Timestamp(timeIntervalSince1970: $0) }
        self.end = try container.decodeIfPresent(Double.self, forKey: .end).map { Timestamp(timeIntervalSince1970: $0) }
        self.id = try container.decodeIfPresent(Int.self, forKey: .id)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if type != .data {
            try container.encode(type, forKey: .type)
        }
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(value, forKey: .value)
        if !samples.isEmpty {
            try container.encode(samples, forKey: .samples)
        }
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(depth, forKey: .depth)
        try container.encodeIfPresent(time?.timeIntervalSince1970, forKey: .time)
        try container.encodeIfPresent(end?.timeIntervalSince1970, forKey: .end)
        try container.encodeIfPresent(id, forKey: .id)
    }
}

// MARK: Equatable

extension Message: Equatable {

}