import Foundation
import Testing
import Soil

@Suite("Component")
struct ComponentTests {

    @Test("Remote storage")
    func testValue() async throws {
        let connection = await BidirectionalConnection()
        let connectionToRemote = await connection.one.apply(encoding: JsonEncoding())
        let connectedRemote = await RemoteStorage(connection: connectionToRemote)

        let connectionToClient = await connection.two.apply(encoding: JsonEncoding())
        let connectedClient = await HostedStorage(hosting: InMemoryStorage(), through: connectionToClient)

        // Send value to bob
        let now = Timestamp.current()
        let path = ["a", "b"]
        await connectedRemote.receive(.integer(123), for: path, at: now).wait()

        #expect(await connection.one.sentMessages == 1)
        #expect(await connection.two.receivedMessages == 1)
        await connection.resetCounters()

        // Check value on bob's side
        do {
            let sample = await connectedClient.currentSample(for: path)
            let existingSample = try #require(sample)
            #expect(existingSample.value == .integer(123))
            #expect(existingSample.timestamp.isVeryClose(to: now))
        }

        // Get value again from alice's side
        do {
            let sample = await connectedRemote.currentSample(for: path)
            let existingSample = try #require(sample)
            #expect(existingSample.value == .integer(123))
            #expect(existingSample.timestamp.isVeryClose(to: now))
        }

        // Two more messages expected
        #expect(await connection.one.sentMessages == 1)
        #expect(await connection.one.receivedMessages == 1)
        #expect(await connection.two.sentMessages == 1)
        #expect(await connection.two.receivedMessages == 1)
        await connection.resetCounters()

        // Delete sample on alice's side
        do {
            await connectedRemote.delete(path: path, from: nil, to: nil, depth: 0).wait()
        }

        // Wait for value
        try await Task.sleep(for: .seconds(0.1))

        #expect(await connection.one.sentMessages == 1)
        #expect(await connection.two.receivedMessages == 1)
        await connection.resetCounters()

        // Check that no value is present on bob's side
        do {
            let all = await connectedClient.samples(for: path)
            #expect(all.isEmpty)
        }

        // Check that no value is present on alice's side
        do {
            let all = await connectedRemote.samples(for: path)
            #expect(all.isEmpty)
        }

        #expect(await connection.one.sentMessages == 1)
        #expect(await connection.one.receivedMessages == 1)
        #expect(await connection.two.sentMessages == 1)
        #expect(await connection.two.receivedMessages == 1)
        await connection.resetCounters()
    }

    @Test("Remove observable")
    func testRemoteObservable() async throws {
        let connection = await BidirectionalConnection()

        let remoteStorage = ObservableStorage(wrapping: InMemoryStorage())
        let connectionToClient = await connection.two.apply(encoding: JsonEncoding())
        let remoteConnectionToClient = await HostedObservable(hosting: remoteStorage, through: connectionToClient)

        #expect(await remoteConnectionToClient.numberOfSubscriptions == 0)

        let connectionToRemote = await connection.one.apply(encoding: JsonEncoding())
        let clientConnectionToRemote = await RemoteObservable(connection: connectionToRemote)
        let clientStorage = InMemoryStorage()

        let subscription = await clientConnectionToRemote.subscribe(clientStorage)

        let path = ["a", "b"]
        let now = Timestamp.current()
        await subscription.include(path, depth: 0).wait()

        // Check delivery of subscription message
        #expect(await connection.one.sentMessages == 1)
        #expect(await connection.two.receivedMessages == 1)
        await connection.resetCounters()

        #expect(await remoteConnectionToClient.numberOfSubscriptions == 1)

        await remoteStorage.receive(.integer(123), for: path, at: now).wait()

        // Message should be transmitted to the client
        try await Task.sleep(for: .seconds(0.1))
        #expect(await connection.two.sentMessages == 1)
        #expect(await connection.one.receivedMessages == 1)
        await connection.resetCounters()

        do {
            let optional = await clientStorage.currentSample(for: path)
            let sample = try #require(optional)
            #expect(sample.value == .integer(123))
            #expect(sample.timestamp.isVeryClose(to: now))
        }
    }

    @Test("Echo subscribed")
    func testSubscribeAndEcho() async throws {
        let connection = await BidirectionalConnection()

        let remoteStorage = ObservableStorage(wrapping: InMemoryStorage())
        let connectionToLocal = await DecodedConnection(wrapping: connection.one, encoding: JsonEncoding())
        let remoteConnectionToLocal = await HostedObservableStorage(host: remoteStorage, through: connectionToLocal)

        #expect(await remoteConnectionToLocal.numberOfSubscriptions() == 0)

        let localStorage = InMemoryStorage()
        let connectionToRemote = await DecodedConnection(wrapping: connection.two, encoding: JsonEncoding())
        let localConnectionToRemote = await RemoteObservableStorage(connection: connectionToRemote)

        let subscription = await localConnectionToRemote.subscribe(localStorage)

        // Subscribe to the target path
        let path = ["a", "b"]
        let now = Timestamp.current()
        await subscription.include(path, depth: 0).wait()

        #expect(await connection.one.receivedMessages == 1)
        #expect(await connection.one.sentMessages == 0)
        #expect(await connection.two.receivedMessages == 0)
        #expect(await connection.two.sentMessages == 1)
        await connection.resetCounters()

        #expect(await remoteConnectionToLocal.numberOfSubscriptions() == 1)

        // Send data to the remote
        await localConnectionToRemote.receive(.integer(123), for: path, at: now).wait()
        try await Task.sleep(for: .seconds(0.1))

        let rCount = await connection.one.receivedMessages
        #expect(rCount == 1)
        let sCount = await connection.one.sentMessages
        #expect(sCount == 1)
        #expect(await connection.two.receivedMessages == 1)
        #expect(await connection.two.sentMessages == 1)
        await connection.resetCounters()

        // Check that it exists locally, i.e. was echoed back

        do {
            let optional = await localStorage.currentSample(for: path)
            let sample = try #require(optional)
            #expect(sample.value == .integer(123))
            #expect(sample.timestamp.isVeryClose(to: now))
        }
    }

    @Test("Byte stream communication")
    func testByteStream() async throws {
        let connection = await BidirectionalStream()

        let remoteStorage = ObservableStorage(wrapping: InMemoryStorage())
        let connectionToLocal = await connection.one.apply(framing: SyncByteLengthFraming()).apply(encoding: JsonEncoding())
        let remoteConnectionToLocal = await HostedObservableStorage(host: remoteStorage, through: connectionToLocal)

        #expect(await remoteConnectionToLocal.connection.isOpen())
        #expect(await remoteConnectionToLocal.numberOfSubscriptions() == 0)

        let localStorage = InMemoryStorage()
        let connectionToRemote =  await connection.two.apply(framing: SyncByteLengthFraming()).apply(encoding: JsonEncoding())
        let localConnectionToRemote = await RemoteObservableStorage(connection: connectionToRemote)

        let subscription = await localConnectionToRemote.subscribe(localStorage)

        // Subscribe to the target path
        let path = ["a", "b"]
        let now = Timestamp.current()
        await subscription.include(path, depth: 0).wait()

        do {
            // Expected bytes: 2 (sync) + 2 (len) + message
            let messageLength = "{\"type\":3,\"depth\":0,\"id\":1,\"path\":[\"a\",\"b\"]}".data(using: .utf8)!.count
            let rCount = await connection.one.receivedBytes
            #expect(rCount == messageLength + 4)
            #expect(await connection.one.sentBytes == 0)
            #expect(await connection.two.receivedBytes == 0)
            let sCount = await connection.two.sentBytes
            #expect(sCount == messageLength + 4)
            await connection.resetCounters()
        }

        #expect(await remoteConnectionToLocal.numberOfSubscriptions() == 1)

        // Send data to the remote (connection two)
        await localConnectionToRemote.receive(.integer(123), for: path, at: now).wait()
        try await Task.sleep(for: .seconds(0.01))

        // Subscription is echoed back, so both sides should have the same bytes sent and received
        do {
            // We don't know the exact number of decimals for the timestamp
            let messageLength = "{\"path\":[\"a\",\"b\"],\"samples\":[{\"value\":[2,123],\"timestamp\":792080931}]}"
                .data(using: .utf8)!.count + 4
            let r1 = await connection.one.receivedBytes
            let s1 = await connection.one.sentBytes
            let r2 = await connection.two.receivedBytes
            let s2 = await connection.two.sentBytes

            #expect(r1 >= messageLength && r1 <= messageLength + 9)
            #expect(r2 >= messageLength && r2 <= messageLength + 9)
            #expect(r1 == s2)
            #expect(r2 == s1)
            await connection.resetCounters()
        }

        // Check that it exists locally, i.e. was echoed back

        do {
            let optional = await localStorage.currentSample(for: path)
            let sample = try #require(optional)
            #expect(sample.value == .integer(123))
            #expect(sample.timestamp.isVeryClose(to: now))
        }
    }
}
