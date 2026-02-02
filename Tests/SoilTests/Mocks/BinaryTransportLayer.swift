import Foundation
import Soil

actor BinaryTransportLayer {

    private var callbacks: [String: (Data) -> Void] = [:]

    nonisolated func connect(id: String, to remote: String) -> BinaryConnection {
        Connection(id: id, remote: remote, layer: self)
    }

    func setCallback(id: String, _ callback: @escaping @Sendable (Data) -> Void) {
        callbacks[id] = callback
    }

    @discardableResult
    func send(_ data: Data, to remote: String) async -> Bool {
        guard let callback = callbacks[remote] else {
            missingCallback = remote
            return false
        }
        callback(data)
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