
/**
 The type of a message used to exchange data between components.
 */
public enum MessageType: Int {

    /// A message containing one or more values
    case value = 0

    /// A request to receive data, including subscriptions and exclusions
    case request = 1

    /// A request for historic values at a path
    case history = 2
}

extension MessageType: Codable {

}
