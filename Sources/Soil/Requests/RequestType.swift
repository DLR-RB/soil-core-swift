
/**
 The type of a request, including type-specific information
 */
enum RequestType {

    /// A subscription or exclusion
    case subscriptionOrExclusion(subscribe: Bool, depth: Int?)

    /// A request for values at a path
    case value(time: Timestamp?, depth: Int?)

    /// A request for historic data at a path
    case history(start: Timestamp?, end: Timestamp?, limit: Int?)
}

extension RequestType {

    /// The message type used in a message
    var messageType: MessageType {
        switch self {
            case .subscriptionOrExclusion: .request
            case .value, .history: .request
        }
    }

    /// The number of expected messages for the request, if it can be determined from the request alone
    var expectedMessages: Int? {
        switch self {
        case .value(_, let depth):
            // If the request targets a single path, then we expect only one message in return
            depth.isNilOrNotSmaller(than: 1) ? nil : 1
        case .subscriptionOrExclusion: 1 // Subscriptions/exclusions always have a single response, if a request id is provided
        case .history: nil // History requests have an unknown number of responses
        }
    }
}