
/**
 The type of a message used to exchange data between components.
 */
public enum MessageType: String, Sendable, CaseIterable {

    /// A message containing one or more samples
    case data = "data"

    /// A request to receive data
    case request = "read"

    /// A request to delete data
    case deletionRequest = "delete"

    /// A request to include a path in a subscription
    case subscriptionInclusion = "include"

    /// A request to exclude a path in a subscription
    case subscriptionExclusion = "exclude"

    /// A request to delete a subscription
    case subscriptionDeletion = "clear"

    /// An acknowledgement for a request
    //case acknowledgement = 6
}