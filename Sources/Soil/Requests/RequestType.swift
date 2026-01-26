
/**
 The type of a request, including type-specific information
 */
enum RequestType {

    /// A subscription inclusion
    case include(depth: Int?)

    /// A subscription exclusion
    case exclude(depth: Int?)

    /// A subscription deletion request
    case deleteSubscription

    /// A request for values at a path
    case data(start: Timestamp?, end: Timestamp?, depth: Int?, limit: Int?)
}

extension RequestType {

    /// The number of expected messages for the request, if it can be determined from the request alone
    var expectedMessages: Int? {
        switch self {
        case .data(_, _, let depth, let limit):
            // If the request targets a single path, then we expect only one message in return
            (depth.isNilOrNotSmaller(than: 1) || limit.isNilOrNotSmaller(than: 1)) ? nil : 1
        case .deleteSubscription, .include, .exclude:
            1 // Subscriptions/exclusions always have a single response, if a request id is provided
        }
    }
}