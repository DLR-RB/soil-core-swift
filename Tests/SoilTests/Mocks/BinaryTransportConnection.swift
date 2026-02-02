import Foundation
import Soil

extension BinaryTransportLayer {

    actor Connection: BinaryConnection {

        private let layer: BinaryTransportLayer

        private let id: String

        private let remote: String

        init(id: String, remote: String, layer: BinaryTransportLayer) {
            self.layer = layer
            self.id = id
            self.remote = remote
        }

        func sendInternal(message: Data) async {
            await layer.send(message, to: remote)
        }

        func onReceiveInternal(_ callback: @escaping @Sendable (Data) -> Void) async {
            await layer.setCallback(id: id, callback)
        }

        nonisolated func send(message: Data) -> Request {
            AsyncRequest {
                await self.sendInternal(message: message)
            }
        }

        nonisolated func onReceive(_ callback: @escaping @Sendable (Data) -> Void) {
            Task {
                await self.onReceiveInternal(callback)
            }
        }
    }
    }