import Foundation
import Soil

/**
 A test class that simulates an encoded message connection between two components
 */
final class BidirectionalConnection {

    let one: Connection

    let two: Connection

    init() async {
        one = .init()
        two = .init()

        await one.setRemote(two)
        await two.setRemote(one)
    }

    func resetCounters() async {
        await one.resetCounters()
        await two.resetCounters()
    }

    actor Connection: EncodedMessageConnection, EncodedMessageReceiver {

        private weak var receiver: EncodedMessageReceiver?

        private weak var remote: EncodedMessageReceiver?

        var sentMessages = 0
        var receivedMessages = 0

        init() { }

        func sendToRemote(_ data: Data) async {
            sentMessages += 1
            await remote?.accept(encodedMessage: data).wait()
        }

        nonisolated func send(message data: Data) -> any Request {
            AsyncRequest {
                await self.sendToRemote(data)
            }
        }

        @discardableResult
        nonisolated func setReceiver(_ receiver: (any EncodedMessageReceiver)?) -> any Request {
            AsyncRequest {
                await self.set(receiver: receiver)
            }
        }

        private func set(receiver: (any EncodedMessageReceiver)?) {
            self.receiver = receiver
        }

        func getReceiver() async -> (any EncodedMessageReceiver)? {
            receiver
        }

        fileprivate func setRemote(_ remote: EncodedMessageReceiver) async {
            self.remote = remote
        }

        @discardableResult
        nonisolated func accept(encodedMessage data: Data) -> any Request {
            AsyncRequest {
                await self.didReceive(encodedMessage: data)
            }
        }

        private func didReceive(encodedMessage data: Data) async {
            receivedMessages += 1
            await receiver?.accept(encodedMessage: data).wait()
        }

        func resetCounters() {
            sentMessages = 0
            receivedMessages = 0
        }

        func isOpen() async -> Bool {
            true
        }

        @discardableResult
        nonisolated func close() -> any Request {
            CompletedRequest()
        }

        func onClose(perform block: @escaping @Sendable () -> Void) async {

        }
    }
}