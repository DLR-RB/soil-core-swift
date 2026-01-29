
/**
 The type of a message used to exchange data between components.
 */
public enum MessageType: Int {

    /// A message containing one or more samples
    case data = 0

    /// A request to receive data
    case request = 1

    /// A request to delete data
    case deletionRequest = 2

    /// A request to include a path in a subscription
    case subscriptionInclusion = 3

    /// A request to exclude a path in a subscription
    case subscriptionExclusion = 4

    /// A request to delete a subscription
    case subscriptionDeletion = 5
}

extension MessageType: Codable {

}
