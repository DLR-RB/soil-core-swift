
/**
 A type that can receive messages.
 */
public protocol MessageReceiver: AnyObject, Sendable {

    /**
     Process a received message.
     - Parameter message: The message to receive
     */
    func didReceive(message: Message) async
}