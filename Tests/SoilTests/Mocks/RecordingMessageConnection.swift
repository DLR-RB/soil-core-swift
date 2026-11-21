import Foundation
import Soil

/**
 A test connection that records all messages sent through it,
 and allows injecting messages as if they were received from a remote.
 */
actor RecordingMessageConnection: MessageConnection {

    /// The messages sent over the connection, in order
    private(set) var sentMessages: [Message] = []

    /// The receiver of incoming messages
    private var receiver: (any MessageReceiver)?

    init() { }

    private func record(_ message: Message) {
        sentMessages.append(message)
    }

    func resetMessages() {
        sentMessages = []
    }

    @discardableResult
    nonisolated func send(message: Message) -> any Request {
        AsyncRequest {
            await self.record(message)
        }
    }

    /**
     Simulate receiving a message from the remote, and wait until the receiver handled it.
     */
    func receive(_ message: Message) async {
        await receiver?.accept(message: message).wait()
    }

    @discardableResult
    nonisolated func setReceiver(_ receiver: (any MessageReceiver)?) -> any Request {
        AsyncRequest {
            await self.set(receiver: receiver)
        }
    }

    private func set(receiver: (any MessageReceiver)?) {
        self.receiver = receiver
    }

    func getReceiver() -> (any MessageReceiver)? {
        receiver
    }

    func isOpen() -> Bool {
        true
    }

    @discardableResult
    nonisolated func close() -> any Request {
        CompletedRequest()
    }

    func onClose(perform block: @escaping @Sendable () -> Void) {

    }
}
