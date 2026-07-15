import Foundation
import Soil

/**
 A test class that simulates a stream connection between two parties.
*/
final class BidirectionalStream {

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

    actor Connection: StreamConnection, StreamReceiver {

        private weak var receiver: StreamReceiver?

        private weak var remote: StreamReceiver?

        var sentBytes = 0
        var receivedBytes = 0

        init() { }

        func sendToRemote(_ bytes: [UInt8]) async {
            await remote?.accept(bytes: bytes).wait()
            sentBytes += bytes.count
        }

        @discardableResult
        nonisolated func send(bytes: [UInt8]) -> any Request {
            AsyncRequest {
                await self.sendToRemote(bytes)
            }
        }

        @discardableResult
        nonisolated func setReceiver(_ receiver: (any StreamReceiver)?) -> any Request {
            AsyncRequest {
                await self.set(receiver: receiver)
            }
        }

        private func set(receiver: (any StreamReceiver)?) {
            self.receiver = receiver
        }

        func getReceiver() -> (any StreamReceiver)? {
            receiver
        }

        fileprivate func setRemote(_ remote: StreamReceiver) async {
            self.remote = remote
        }

        public nonisolated func accept(bytes: [UInt8]) -> any Request {
            AsyncRequest {
                await self.didReceive(bytes: bytes)
            }
        }

        private func didReceive(bytes: [UInt8]) async {
            await receiver?.accept(bytes: bytes).wait()
            receivedBytes += bytes.count
        }

        func resetCounters() {
            sentBytes = 0
            receivedBytes = 0
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