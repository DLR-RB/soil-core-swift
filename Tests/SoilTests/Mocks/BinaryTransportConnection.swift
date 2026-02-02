import Foundation
import Soil

extension BinaryTransportLayer {

    actor Connection: EncodedMessageConnection {

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

        nonisolated func send(message: Data) -> Request {
            AsyncRequest {
                await self.sendInternal(message: message)
            }
        }

        func setReceiver(_ receiver: EncodedMessageReceiver) async {
            await layer.setReceiver(receiver, for: id)
        }
    }
}