

/**
 Encapsulate a remote component that provides storage to treat it like a local storage
 */
public actor RemoteStorage {

    private let connection: any MessageConnection

    private let requests: RemoteDataRequests

    public init(connection: any MessageConnection) async {
        self.connection = connection
        self.requests = .init()

        // Register to receive messages from the component
        await connection.setReceiver(self)
    }

    private func deleteInternal(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        // TODO: Track deletion requests
        let message = Message.delete(path, from: start, to: end, depth: depth, id: nil)
        send(message)
    }

    private func transmit(_ tree: SampleTree, for path: Path) {
        if !tree.samples.isEmpty {
            send(.samples(tree.samples, for: path))
        }
        for (name, child) in tree.children {
            transmit(child, for: path + [name])
        }
    }

    /**
     Send a message to the component.
     - Parameter message: The message to send.
     - Note: If no message callback is available, then the message is discarded.
     - Returns: The request to send the message
     */
    @discardableResult
    private func send(_ message: Message) -> any Request {
        connection.send(message: message)
    }

    /*
     The id used for the most recent request

     This id is always incremented for the next request,
     so that the first request of the component has id `1`.
     */
    private var lastRequestId = 0

    /**
     Get the request id for the component.

     The request id is incremented from 1,
     while a connection to the component is active.
     */
    private func nextRequestId() -> Int {
        lastRequestId += 1
        return lastRequestId
    }

    private func startRequestTimeout(seconds: Double, id: Int) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

            guard !Task.isCancelled, let self else { return }
            await self.reachedTimeout(forRequest: id)
        }
    }

    private func reachedTimeout(forRequest id: Int) {
        requests.cancel(request: id)
    }

    private func request(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limit: Int?) async -> SampleTree {
        let id = nextRequestId()
        // Send the request message to the remote
        // If it's not delivered, then the timeout will be triggered
        send(.request(path, from: start, to: end, limit: limit, depth: depth, id: id))

        // TODO: Specify timeout
        let timeoutTask = startRequestTimeout(seconds: 30, id: id)
        // Store the request and wait for the data (with a timeout)
        return await withCheckedContinuation { continuation in
            let request = DataRequest(
                path: path,
                start: start,
                end: end,
                depth: depth,
                limit: limit,
                continuation: continuation,
                timeout: timeoutTask)
            requests.add(request, for: id)
        }
    }

    // MARK: Response handling

    public func didReceive(message: Message) {
        switch message.type {
        case .data:
            didReceive(data: message)
        case .request:
            break
        case .deletionRequest:
            break
        case .subscriptionInclusion, .subscriptionDeletion, .subscriptionExclusion:
            break
        }
    }

    /**
     Process a data message, by checking which request it matches
     - Parameter message: The received data message
     */
    private func didReceive(data message: Message) {
        // Note: We know that the message is a data message

        // Pass the request to the handler, which checks if the message
        // matches an active request
        requests.didReceive(message)
    }
}

extension RemoteStorage: MessageReceiver {

}

// MARK: Storage

extension RemoteStorage: Storage {

    /**
     Receive a tree for a path.

     This is the singular function to inject data into a component.

     The provided tree can contain multiple values for each node, and be of arbitrary depth.

     Components may choose to ignore parts of the tree due to access rights or other reasons.
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     - Note: This function is not marked `async`, because it is viewed as a request to store data.
       The data does not actually need to be stored when the function returns, and should return as fast as possible.
     */
    @discardableResult
    public nonisolated func receive(_ tree: SampleTree, for path: Path) -> Request {
        AsyncRequest {
            await self.transmit(tree, for: path)
        }
    }

    /**
     Read a data tree for a given path within a given interval.

     This is the singular function to serve all data retrieval needs.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     The `limitPerNode` is applied in sort order.

     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels below the path to include in the result
     - Parameter limitPerNode: The maximum number of values to return for each node of the tree (defaults to `nil`, e.g. no limit)
     - Returns: The tree with the given depth, limited to the maximum count per node, for the requested interval.
     - Note: This function is `async`, because providing the data may take some time.
       It could be retrieved over a network, from an otherwise slow database, or from other components.
     */
    public func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) async -> SampleTree {
        await request(path: path, from: start, to: end, depth: depth, limit: limitPerNode)
    }


    /**
     Delete data from the storage.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     */
    @discardableResult
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> Request {
        AsyncRequest {
            await self.deleteInternal(path: path, from: start, to: end, depth: depth)
        }
    }
}