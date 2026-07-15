
/**
 A sequence of messages to transmit that belong to a batch.
 */
private final class MessageSequence {

    /// The id of the original message
    let request: Int?

    /// The list of messages to send in this batch
    var messages: [(path: Path, value: Value, time: Timestamp?)] = []

    // The number of messages received for transmission
    var received = 0

    // The total number of messages expected for this batch
    var total = 0

    /**
     Create a batch until all messages to transmit are received.
     */
    init(request: Int?) {
        self.request = request
    }

    /**
     Update the expected message count from a batch message.
     */
    func update(count: Int?) {
        guard let count else {
            return
        }
        guard count > total else {
            return
        }
        total = count
    }

    /**
     Add the contents of a batch message
     */
    func add(message: Message) {
        add(tree: message.data, path: message.path)
    }

    /**
     Add a sample for a path to the message list.
     */
    private func add(path: Path, value: Value, time: Timestamp?) {
        messages.append((path, value, time))
    }

    /**
     Add all samples of a tree to the message list
     */
    private func add(tree: any SampleTree, path: Path) {
        for sample in tree.samples {
            add(path: path, value: sample.value, time: sample.timestamp)
        }
        for (name, child) in tree.children {
            add(tree: child, path: path + [name])
        }
    }

    /// Indicate if all messages of a batch have are available for transmission
    var isComplete: Bool {
        received == total
    }

    /**
     Compute the total count and the batch id to use for the outgoing messages.
     */
    func countAndId() -> (count: Int?, id: Int?) {
        if let request {
            return (messages.count, request)
        }
        // No request means we only need an id if there is more than one message
        guard messages.count > 1 else {
            return (nil, nil)
        }
        let id = Int(UInt16.random(in: .min...UInt16.max))
        return (messages.count, id)
    }
}

/**
 A converter that wraps a connection that sends complex messages and converts them to simple value messages.

 Messages over arbitrary connections may contain multiple samples or additional child data.
 The splitter splits these complex messages into multiple smaller messages only containing a single value,
 to support message encodings that can't handle these fields.

 For trees already split into multiple messages, it waits until all are received,
 and then sets the total count with the same request id for all simple messages.
 */
public actor DataMessageSplitter {

    /// The wrapped connection for which to split the outgoing messages
    private let connection: MessageConnection

    /// The original receiver of the incoming messages
    private var receiver: (any MessageReceiver)?

    /// The logger for internal errors
    private var log: Logger?

    /// The cached outgoing message batches,
    /// so that the total number of messages can be calculated
    private var outgoingMessages: [Int : MessageSequence] = [:]

    /// In internal flag to only once create a log message if no receiver is present
    private var shouldWarnAboutMissingReceiver = true

    /**
     Wrap a connection to only transmit simple data messages in batches.
     - Parameter connection: The connection for which to split outgoing messages
     */
    public init(wrapping connection: MessageConnection) async {
        self.connection = connection
        await connection.setReceiver(self).wait()
    }

    // MARK: Sending

    /**
     Internal async function to process incoming messages.
     The data messages are tracked if needed, the rest is directly forwarded to the receiver.
     */
    private func send(_ message: Message) async {
        // Intercept data messages, forward the rest
        switch message.type {
            case .data:
                await send(data: message)
            default:
                await connection.send(message: message).wait()
        }
    }

    /**
     Transmit a message split into several simple messages if needed.
     */
    private func send(data message: Message) async {
        // Create a sequence to store the message,
        // until all other messages of the same request are present.
        // Waiting is needed to calculate the new total number of messages,
        // which will be different from the `count` previously in the messages
        let sequence = createOrGet(request: message.id)
        sequence.update(count: message.count)
        sequence.add(message: message)

        guard sequence.isComplete else {
            // Wait for remaining messages
            // TODO: Add timeout to send/discard incomplete sequence
            return
        }
        await send(sequence: sequence)
        remove(sequence: sequence)
    }

    /**
     Send a complete message batch after all parts of the original batch have been received.
     */
    private func send(sequence: MessageSequence) async {
        let (count, id) = sequence.countAndId()
        for message in sequence.messages {
            let out = Message.value(message.value, for: message.path, at: message.time, inResponseTo: id, withCount: count)
            await connection.send(message: out).wait()
        }
    }

    /**
     Create a message sequence for transmission.

     If no request id is provided, then the sequence is not stored.
     */
    private func createOrGet(request: Int?) -> MessageSequence {
        guard let request else {
            // No request id provided, so the sequence will be handled
            // completely without storing it
            return MessageSequence(request: nil)
        }
        if let existing = outgoingMessages[request] {
            return existing
        }
        let sequence = MessageSequence(request: request)
        outgoingMessages[request] = sequence
        return sequence
    }

    /**
     Remove a tracked batch from the cache after completion.
     */
    private func remove(sequence: MessageSequence) {
        guard let request = sequence.request else {
            return
        }
        outgoingMessages[request] = nil
    }

    /**
     Remove all incomplete message batches due to connection closure.
     */
    private func removeAll() {
        outgoingMessages.removeAll()
    }
}

// MARK: Message Connection

extension DataMessageSplitter: MessageConnection {

    /**
     Send a message to the wrapped connection.
     - Parameter message: The message to send
     - Returns: A request to await for completion of the request, which may not include transmission.
     - Note: The message may not be immediately forwarded, if it is part of a batch.
             If the message consists of a complex tree, then it is separated into multiple value messages.
     */
    public nonisolated func send(message: Message) -> any Request {
        AsyncRequest {
            await self.send(message)
        }
    }
}

extension DataMessageSplitter: MessageDistributor {

    /**
     Set the receiver for messages coming in over this connection.
     - Parameter receiver: The receiver of incoming messages.
     */
    @discardableResult
    public nonisolated func setReceiver(_ receiver: (any MessageReceiver)?) -> any Request {
        AsyncRequest {
            await self.set(receiver: receiver)
        }
    }

    private func set(receiver: (any MessageReceiver)?) async {
        self.receiver = receiver
    }

    public func getReceiver() async -> (any MessageReceiver)? {
        receiver
    }
}

// MARK: Connection

extension DataMessageSplitter: Connection {

    /// Indicate if the connection is open and can receive and transmit data
    public func isOpen() async -> Bool {
        await connection.isOpen()
    }

    /**
     * Close the connection
     - Returns: A request to optionally wait for closure.
     */
    public nonisolated func close() -> any Request {
        connection.close()
    }

    /**
     * Execute a closure when the connection is closed
     * - Parameter block: The closure to execute
     */
    public func onClose(perform block: @escaping @Sendable () -> Void) async {
        await connection.onClose { [weak self] in
            if let self {
                Task {
                    await self.removeAll()
                }
            }
            block()
        }
    }
}

// MARK: Message Receiver

extension DataMessageSplitter: MessageReceiver {

    /**
     Process a message received over the connection.
     - Note: This message is called automatically by the connection, and should not be called manually.
     - Parameter message: The received message
     */
    public func didReceive(message: Message) async {
        guard let receiver else {
            if shouldWarnAboutMissingReceiver {
                log?.warning("No receiver for message")
                shouldWarnAboutMissingReceiver = false
            }
            return
        }
        shouldWarnAboutMissingReceiver = true // Reset flag
        await receiver.didReceive(message: message)
    }
}
