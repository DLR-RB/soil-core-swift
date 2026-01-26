
/**
 The type of a message used to exchange data between components.
 */
public enum MessageType: Int {

    /// A message containing one or more values
    case data = 0

    /// A request to receive data, including subscriptions and exclusions
    case request = 1

    /// A request to include a path in a subscription
    case subscriptionInclusion = 2

    /// A request to exclude a path in a subscription
    case subscriptionExclusion = 3

    /// A request to delete a subscription
    case subscriptionDeletion = 4
}

extension MessageType: Codable {

}
