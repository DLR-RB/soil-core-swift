import Foundation

/**
 A message to transmit between components.

 This structure implements all message types (see ``MessageType``) in a single message through optional properties.
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
     A data associated with the `path`.

     Usage:
     - Data message: The tree associated with the path
     */
    public let data: any SampleTree

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
    public init(
        type: MessageType,
        path: Path,
        time: Timestamp? = nil,
        data: any SampleTree = ImmutableSampleTree.empty,
        count: Int? = nil,
        depth: Int? = nil,
        end: Timestamp? = nil,
        id: Int? = nil
    ) {
        self.type = type
        self.path = path
        self.data = data
        self.count = count
        self.depth = depth
        self.time = time
        self.end = end
        self.id = id
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
            data: ImmutableSampleTree(value: value, timestamp: timestamp),
            count: totalMessages,
            id: request)
    }

    /**
     Create a push message to transmit a value, after converting it to a SOIL value.
     - Parameter path: The path of the value to transmit.
     - Parameter value: The value associated with the path.
     - Parameter timestamp: The timestamp associated with the value. `nil` indicates current time.
     - Parameter request: The optional request id, if this is a response, or if an acknowledgement is expected.
     - Parameter totalMessages: The total number of messages in response to the request
     - Throws: An error, if the value can't be converted to a SOIL value
     - Note: The message type will be set to `data`
     */
    // Disfavored, so that literals use the non-throwing `Value` overload
    @_disfavoredOverload
    public static func value(_ value: some ValueConvertible, for path: Path, at timestamp: Timestamp? = nil, inResponseTo request: Int? = nil, withCount totalMessages: Int? = nil) throws -> Self {
        .value(try value.soilValue, for: path, at: timestamp, inResponseTo: request, withCount: totalMessages)
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
            data: ImmutableSampleTree(samples: samples),
            count: totalMessages,
            id: request)
    }

    /**
     Create a message with a tree.
     - Parameter path: The path of the value to transmit.
     - Parameter tree: The tree associated with the path.
     - Parameter request: The optional id of the request that prompted the message.
     - Parameter totalMessages: The total number of messages in response to the request
     - Note: The message type will be set to `data`
     */
    public static func tree(_ tree: any SampleTree, for path: Path, inResponseTo request: Int? = nil, totalMessages: Int? = nil) -> Self {
        .init(
            type: .data,
            path: path,
            data: tree,
            count: totalMessages,
            id: request)
    }

    /**
     Create a message with a tree, after converting a value to a SOIL tree.
     - Parameter value: The value to convert to the tree associated with the path.
     - Parameter path: The path of the root node of the tree.
     - Parameter timestamp: The timestamp set for all samples of the tree that don't have one. `nil` indicates current time.
     - Parameter request: The optional id of the request that prompted the message.
     - Parameter totalMessages: The total number of messages in response to the request
     - Throws: An error, if the value can't be converted to a SOIL tree
     - Note: The message type will be set to `data`
     */
    public static func tree(_ value: some SampleTreeConvertible, for path: Path, at timestamp: Timestamp? = nil, inResponseTo request: Int? = nil, totalMessages: Int? = nil) throws -> Self {
        let tree = try value.sampleTree
        return .tree(timestamp.map { tree.withTimestamp($0) } ?? tree, for: path, inResponseTo: request, totalMessages: totalMessages)
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
     - Note: The message type will be set to `subscriptionInclusion`
     */
    public static func include(_ path: Path, depth: Int? = nil) -> Self {
        subscriptionRequest(.subscriptionInclusion, for: path, with: depth)
    }

    /**
     Create a request for an exclusion from a subscription.
     - Parameter path: The path to exclude.
     - Parameter depth: The number of levels below the path to exclude.
     - Note: The message type will be set to `subscriptionExclusion`
     */
    public static func exclude(_ path: Path, depth: Int? = nil) -> Self {
        subscriptionRequest(.subscriptionExclusion, for: path, with: depth)
    }

    /**
     Create a request to delete a subscription.
     - Parameter path: The path for which to delete subscription rules
     - Note: The message type will be set to `subscriptionDeletion`
     */
    public static func deleteRules(at path: Path, depth: Int? = nil) -> Self {
        subscriptionRequest(.subscriptionDeletion, for: path, with: depth)
    }

    /**
     Create a request for a subscription inclusion, exclusion or deletion.
     - Parameter type: The message type to set
     - Parameter path: The path to include, exclud, or delete.
     - Parameter depth: The number of levels below the path to include/exclude/delete.
     */
    public static func subscriptionRequest(_ type: MessageType, for path: Path, with depth: Int? = nil) -> Self {
        .init(
            type: type,
            path: path,
            depth: depth)
    }
}

// MARK: Equatable

extension Message: Equatable {

    /**
     Compare two messages, allowing for a small difference in all timestamps.

     This is useful when comparing messages that passed through a lossy encoding,
     e.g. timestamps converted to floating point seconds since 1970.
     - Parameter other: The message to compare to
     - Parameter timeTolerance: The maximum allowed difference between timestamps (in seconds)
     - Returns: `true`, if all properties are equal and all timestamps (including those of samples) are within the tolerance
     */
    public func isEqual(to other: Message, timeTolerance: TimeInterval) -> Bool {
        type == other.type &&
        path == other.path &&
        count == other.count &&
        depth == other.depth &&
        id == other.id &&
        time.isEqual(to: other.time, tolerance: timeTolerance) &&
        end.isEqual(to: other.end, tolerance: timeTolerance) &&
        data.isEqual(to: other.data, timeTolerance: timeTolerance)
    }

    /// Compare two messages, requiring all timestamps to match exactly
    public static func == (_ lhs: Message, _ rhs: Message) -> Bool {
        lhs.isEqual(to: rhs, timeTolerance: 0)
    }
}

// MARK: Description

extension Message: CustomStringConvertible {

    public var description: String {
        var content: [String] = [
            "type: \(type)"
        ]

        if !path.isEmpty {
            content.append("path: \(path)")
        }
        if let count {
            content.append("count: \(count)")
        }
        if let depth {
            content.append("depth: \(depth)")
        }
        if let id {
            content.append("id: \(id)")
        }
        if let time {
            content.append("time: \(time)")
        }
        if let end {
            content.append("end: \(end)")
        }
        if !data.isEmpty {
            content.append("data:")
            content.append(contentsOf: data.describe(indentLevel: 1))
        }
        return content.joined(separator: "\n")
    }
}
