import Foundation
import Soil

actor BinaryTransportLayer {

    private var receivers: [String: any EncodedMessageReceiver] = [:]

    nonisolated func connect(id: String, to remote: String) -> EncodedMessageConnection {
        Connection(id: id, remote: remote, layer: self)
    }

    func setReceiver(_ receiver: EncodedMessageReceiver, for id: String) {
        receivers[id] = receiver
    }

    @discardableResult
    func send(_ data: Data, to remote: String) async -> Bool {
        guard let receiver = receivers[remote] else {
            missingCallback = remote
            return false
        }
        await receiver.didReceive(encodedMessage: data)
        numberOfMessages += 1
        self.complete()
        return true
    }

    private var continuation: CheckedContinuation<Void, Never>?

    var missingCallback: String?

    var numberOfMessages = 0

    private var isDone = false

    private func complete() {
        self.isDone = true
        self.continuation?.resume()
        self.continuation = nil
    }

    func waitForDelivery() async {
        if isDone { return }
        await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }

    func resetMessageCount() {
        numberOfMessages = 0
    }
}