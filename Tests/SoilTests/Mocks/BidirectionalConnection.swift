import Foundation
import Soil

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
            await remote?.didReceive(encodedMessage: data)
            sentMessages += 1
        }

        nonisolated func send(message data: Data) -> Request {
            AsyncRequest {
                await self.sendToRemote(data)
            }
        }

        func setReceiver(_ receiver: EncodedMessageReceiver) async {
            self.receiver = receiver
        }

        fileprivate func setRemote(_ remote: EncodedMessageReceiver) async {
            self.remote = remote
        }

        func didReceive(encodedMessage data: Data) async {
            await receiver?.didReceive(encodedMessage: data)
            receivedMessages += 1
        }

        func resetCounters() {
            sentMessages = 0
            receivedMessages = 0
        }
    }
}