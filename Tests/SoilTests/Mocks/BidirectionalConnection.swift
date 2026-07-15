import Foundation
import Soil

/**
 A test class that simulates a frame connection between two components
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

    actor Connection: FrameConnection, FrameReceiver {

        private weak var receiver: FrameReceiver?

        private weak var remote: FrameReceiver?

        var sentMessages = 0
        var receivedMessages = 0

        init() { }

        func sendToRemote(_ data: Data) async {
            sentMessages += 1
            await remote?.accept(frame: data).wait()
        }

        nonisolated func send(message data: Data) -> any Request {
            AsyncRequest {
                await self.sendToRemote(data)
            }
        }

        @discardableResult
        nonisolated func setReceiver(_ receiver: (any FrameReceiver)?) -> any Request {
            AsyncRequest {
                await self.set(receiver: receiver)
            }
        }

        private func set(receiver: (any FrameReceiver)?) {
            self.receiver = receiver
        }

        func getReceiver() async -> (any FrameReceiver)? {
            receiver
        }

        fileprivate func setRemote(_ remote: FrameReceiver) async {
            self.remote = remote
        }

        @discardableResult
        nonisolated func accept(frame data: Data) -> any Request {
            AsyncRequest {
                await self.didReceive(frame: data)
            }
        }

        private func didReceive(frame data: Data) async {
            receivedMessages += 1
            await receiver?.accept(frame: data).wait()
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