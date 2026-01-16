

enum RequestType {

    case subscriptionOrExclusion(subscribe: Bool, depth: Int?)

    case value(time: Timestamp?, depth: Int?)

    case history(start: Timestamp?, end: Timestamp?, limit: Int?)
}

extension RequestType {

    var messageType: MessageType {
        switch self {
            case .subscriptionOrExclusion: .request
            case .value, .history: .request
        }
    }

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