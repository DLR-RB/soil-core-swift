
/**
 A message connection that prints all incoming and outgoing messages
 */
actor PrintingMessageConnection: MessageConnection {

    private let connection: any MessageConnection

    private var receiver: (any MessageReceiver)?

    /**
     Wrap a connection to print all messages.
     */
    public init(connection: any MessageConnection) {
        self.connection = connection
    }

    nonisolated func send(message: Message) -> any Request {
        print("Out: \(message)")
        return connection.send(message: message)
    }
}

extension PrintingMessageConnection: Connection {

    func isOpen() async -> Bool {
        await connection.isOpen()
    }

    nonisolated func close() -> any Request {
        connection.close()
    }

    func onClose(perform block: @escaping @Sendable () -> Void) async {
        await connection.onClose(perform: block)
    }
}

extension PrintingMessageConnection: MessageDistributor {

    nonisolated func setReceiver(_ receiver: (any MessageReceiver)?) -> any Request {
        AsyncRequest {
            await self.setReceiverInternal(receiver)
        }
    }

    private func setReceiverInternal(_ receiver: (any MessageReceiver)?) {
        self.receiver = receiver
    }

    func getReceiver() async -> (any MessageReceiver)? {
        return self.receiver
    }
}

extension PrintingMessageConnection: MessageReceiver {

    nonisolated func accept(message: Message) -> any Request {
        AsyncRequest {
            await self.acceptInternal(message: message)
        }
    }

    private func acceptInternal(message: Message) async {
        print("Out: \(message)")
        guard let receiver else {
            return
        }
        await receiver.accept(message: message).wait()
    }
}