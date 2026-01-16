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
     - Value message: Indicate the total number of messages for the request
     - Request: Indicate the maximum depth (Negative values are treated as no limit)
     - History: Limit the number of returned samples (negative values are treated as no limit)
     */
    public let count: Int?

    /**
     A subscription indicator

     Usage:
     - Subscription message: Indicate a subscription (`true`) or exclusion (`false`).
     // TODO: Move this into the message type (request, subscribe, exclude) to simplify
     */
    public let subscribe: Bool?

    /**
     A date.

     Usage:
     - Value message: Used together with `value` to indicate the timestamp (`nil` represents the current time).
     - Request message: The point in time for which values are requested (`nil` represents the most recent values).
     - History request: Used as the `start` date of history requests.
     */
    public let time: Timestamp?

    /**
     The end date using in history requests.

     Usage:
     - History request: Used to indicate the end of a request interval.
     */
    public let end: Timestamp?

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
        time: Timestamp? = nil,
        samples: [Sample]? = nil,
        count: Int? = nil,
        subscribe: Bool? = nil,
        end: Timestamp? = nil,
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
     Create an empty message to acknowledge a subscription/exclusion or history request.
     - Parameter path: The path of the original request.
     - Parameter request: The id of the original request.
     - Parameter timestamp: An optional timestamp to signal the processing time of the request.
     - Note: The message type will be set to `value`
     */
    public static func acknowledge(path: Path, request: Int, timestamp: Timestamp? = nil) -> Self {
        .init(
            type: .value,
            path: path,
            time: timestamp,
            request: request)
    }

    /**
     Create a push message to transmit a value.
     - Parameter path: The path of the value to transmit.
     - Parameter value: The value associated with the path.
     - Parameter timestamp: The timestamp associated with the value. `nil` indicates current time.
     - Parameter request: The optional request id, if this is a response, or if an acknowledgement is expected.
     - Parameter totalMessages: The total number of messages in response to the request
     - Note: The message type will be set to `value`
     */
    public static func value(path: Path, value: Value, timestamp: Timestamp? = nil, request: Int? = nil, totalMessages: Int? = nil) -> Self {
        .init(
            type: .value,
            path: path,
            value: value,
            time: timestamp,
            count: totalMessages,
            request: request)
    }

    /**
     Create a message with several samples.
     - Parameter path: The path of the value to transmit.
     - Parameter samples: The samples associated with the path.
     - Parameter request: The optional id of the request that prompted the message.
     - Parameter totalMessages: The total number of messages in response to the request
     - Note: The message type will be set to `value`
     */
    public static func values(path: Path, samples: [Sample], request: Int? = nil, totalMessages: Int? = nil) -> Self {
        .init(
            type: .value,
            path: path,
            samples: samples,
            count: totalMessages,
            request: request)
    }

    /**
     Create a message for a history request.
     - Parameter path: The path for which history is requested.
     - Parameter start: The start date of the requested interval. `nil` indicates beginning of time.
     - Parameter end: The end date of the requested interval. `nil` indicates end of time.
     - Parameter limit: The maximum number of samples to send, counting from `start`
     - Parameter request: The optional request id to include in responses.
     - Note: The message type will be set to `history`
     */
    public static func history(path: Path, start: Timestamp? = nil, end: Timestamp? = nil, limit: Int? = nil, request: Int? = nil) -> Self {
        .init(
            type: .history,
            path: path,
            time: start,
            count: limit,
            end: end,
            request: request)
    }

    /**
     Create a message that requests values.
     - Parameter path: The path for which values are requested.
     - Parameter time: The point in time for which values are requested. `nil` indicates current time. The last value before or at the given time is returned.
     - Parameter depth: The number of levels below the path that should be included in the responses.
     - Parameter request: An optional request id to identify the responses.
     - Note: The message type will be set to `request`
     */
    public static func request(path: Path, beforeOrAt time: Timestamp? = nil, depth: Int? = nil, request: Int? = nil) -> Self {
        .init(
            type: .request,
            path: path,
            time: time,
            count: depth,
            request: request)
    }

    /**
     Create a subscription request.
     - Parameter path: The path to subscribe to.
     - Parameter depth: The number of levels below the path to subscribe to.
     - Parameter request: An optional request id, with which the component can respond.
     - Note: The message type will be set to `request`
     */
    public static func subscribe(path: Path, depth: Int? = nil, request: Int? = nil) -> Self {
        subscribeOrExclude(path: path, subscribe: true, depth: depth, request: request)
    }

    /**
     Create a request for an exclusion from a subscription.
     - Parameter path: The path to exclude.
     - Parameter depth: The number of levels below the path to exclude.
     - Parameter request: An optional request id, with which the component can respond.
     - Note: The message type will be set to `request`
     */
    public static func exclude(path: Path, depth: Int? = nil, request: Int? = nil) -> Self {
        subscribeOrExclude(path: path, subscribe: false, depth: depth, request: request)
    }

    /**
     Create a request for a subscription or exclusion.
     - Parameter path: The path to subscribte to or exclude.
     - Parameter subscribe: Indicate if this is a subscription or exclusion
     - Parameter depth: The number of levels below the path to sucbribe/exclude.
     - Parameter request: An optional request id, with which the component can respond.
     - Note: The message type will be set to `request`
     */
    public static func subscribeOrExclude(path: Path, subscribe: Bool, depth: Int? = nil, request: Int? = nil) -> Self {
        .init(
            type: .request,
            path: path,
            count: depth,
            subscribe: subscribe,
            request: request)
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