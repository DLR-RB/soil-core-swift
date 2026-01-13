import Foundation

/**
 A message to transmit between components.

 This structure implements all three message types (see ``MessageType``) in a single message through optional properties.
 */
public struct Message {

    /// Indicate the message type (may be ommited for a value message)
    public let type: MessageType

    /// The identifying path of the data contained at the top level of this message
    public let path: Path

    /**
     A value associated with the `path`.

     Usage:
     - Value message: The value for a path
     - Note: If `time` is set, then it represents the timestamp of the value,
     otherwise the value is treated as a current time value.

     A future use may be for subscriptions to indicate the default value of a path.
     */
    public let value: Value?

    /**
     A sample associated with the `path`.

     Usage:
     - Value message: Used in responses to history data requests
     */
    public let samples: [Sample]?

    /**
     A generic count used as a limit or depth.

     Usage:
     - Value message: Indicate the number of remaining messages for the request
     - Request: Indicate the maximum depth (Negative values are treated as no limit)
     - History: Limit the number of returned samples (negative values are treated as no limit)
     */
    public let count: Int?

    /**
     A subscription indicator

     Usage:
     - Subscription message: Indicate a subscription (`true`) or exclusion (`false`).
     - History message: Indicate a subscription to the path (depth `0`)
     */
    public let subscribe: Bool?

    /**
     A date.

     Usage:
     - Value message: Used together with `value` to indicate the timestamp (`nil` represents the current time).
     - Request message: The point in time for which values are requested (`nil` represents the most recent values).
     - History request: Used as the `start` date of history requests.
     */
    public let time: Date?

    /**
     The end date using in history requests.

     Usage:
     - History request: Used to indicate the end of a request interval.
     */
    public let end: Date?

    /**
     The id of the request.

     Usage:
     - Value message: Identifies the request that this value corresponds to.
     - Request message: An identifier to include in responses to the request.
     - History request: An identifier to include in responses to the request.
     */
    public let request: Int?

    /**
     Additional messages relative to this message.

     These are used to send tree structures more efficiently.
     */
    //let children: [TransportLayerMessage]?

    public init(
        type: MessageType,
        path: Path,
        value: Value? = nil,
        time: Date? = nil,
        samples: [Sample]? = nil,
        count: Int? = nil,
        subscribe: Bool? = nil,
        end: Date? = nil,
        request: Int? = nil
        //children: [TransportLayerMessage]? = nil
    ) {
        self.type = type
        self.path = path
        self.value = value
        self.samples = samples
        self.count = count
        self.subscribe = subscribe
        self.time = time
        self.end = end
        self.request = request
        //self.children = children
    }
}

extension Message {

    /**
     Create a push message to transmit a value
     */
    public static func value(path: Path, value: Value, timestamp: Date? = nil, request: Int? = nil, remainingMessages: Int? = nil) -> Self {
        .init(
            type: .value,
            path: path,
            value: value,
            time: timestamp,
            count: remainingMessages,
            request: request)
    }

    public static func values(path: Path, samples: [Sample], request: Int? = nil, remainingMessages: Int? = nil) -> Self {
        .init(
            type: .value,
            path: path,
            samples: samples,
            count: remainingMessages,
            request: request)
    }

    public static func history(path: Path, start: Date? = nil, end: Date? = nil, limit: Int? = nil, request: Int? = nil) -> Self {
        .init(
            type: .history,
            path: path,
            time: start,
            count: limit,
            end: end,
            request: request)
    }

    public static func request(path: Path, beforeOrAt time: Date? = nil, depth: Int? = nil, request: Int? = nil) -> Self {
        .init(
            type: .request,
            path: path,
            time: time,
            count: depth,
            request: request)
    }

    public static func subscribe(path: Path, depth: Int? = nil, request: Int? = nil) -> Self {
        .init(
            type: .request,
            path: path,
            count: depth,
            subscribe: true,
            request: request)
    }

    public static func exclude(path: Path, depth: Int? = nil) -> Self {
        .init(
            type: .request,
            path: path,
            count: depth,
            subscribe: false)
    }
}

extension Message: Codable {

    enum CodingKeys: Int, CodingKey {
        case type = 0
        case path = 1
        case value = 2
        case samples = 3
        case count = 4
        case subscribe = 5
        case time = 6
        case end = 7
        case request = 8
    }
}

extension Message: Equatable {

}