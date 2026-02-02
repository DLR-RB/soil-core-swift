import Foundation
import Testing
import Soil

@Suite("Component")
struct ComponentTests {
    @Test("Remote storage")
    func testValue() async throws {

        let layer = BinaryTransportLayer()
        let rawConnectionToRemote = layer.connect(id: "client", to: "remote")
        let connectionToRemote = await DecodedConnection(wrapping: rawConnectionToRemote, encoding: JsonEncoding())
        let storage = InMemoryStorage()

        let connectedRemote = await RemoteStorage(connection: connectionToRemote)

        let rawConnectionToClient = layer.connect(id: "remote", to: "client")
        let connectionToClient = await DecodedConnection(wrapping: rawConnectionToClient, encoding: JsonEncoding())
        let connectedClient = await HostedStorage(hosting: storage, through: connectionToClient)

        // Send value to bob
        let now = Timestamp.current()
        let path = ["a", "b"]
        await connectedRemote.receive(.integer(123), for: path, at: now).wait()

        // Wait for value
        await layer.waitForDelivery()
        #expect(await layer.numberOfMessages == 1)

        try await Task.sleep(for: .seconds(0.1))

        // Check value on bob's side
        do {
            let sample = await storage.currentSample(for: path)
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

        #expect(await layer.numberOfMessages == 3) // Two more messages expected

        // Delete sample on alice's side
        do {
            await connectedRemote.delete(path: path, from: nil, to: nil, depth: 0).wait()
        }

        // Wait for value
        await layer.waitForDelivery()
        try await Task.sleep(for: .seconds(0.1))

        #expect(await layer.numberOfMessages == 4) // One more message expected

        try await Task.sleep(for: .seconds(0.1))

        // Check that no value is present on bob's side
        do {
            let all = await storage.samples(for: path)
            #expect(all.isEmpty)
        }

        // Check that no value is present on alice's side
        do {
            let all = await connectedRemote.samples(for: path)
            #expect(all.isEmpty)
        }

        #expect(await layer.numberOfMessages == 6) // Two more messages expected
    }

    @Test("Remove observable")
    func testRemoteObservable() async throws {

        let layer = BinaryTransportLayer()

        let remoteStorage = ObservableStorage(wrapping: InMemoryStorage())
        let rawConnectionToClient = layer.connect(id: "remote", to: "client")
        let connectionToClient = await DecodedConnection(wrapping: rawConnectionToClient, encoding: JsonEncoding())
        let remoteConnectionToClient = await HostedObservable(hosting: remoteStorage, through: connectionToClient)

        let rawConnectionToRemote = layer.connect(id: "client", to: "remote")
        let connectionToRemote = await DecodedConnection(wrapping: rawConnectionToRemote, encoding: JsonEncoding())
        let clientConnectionToRemote = await RemoteObservable(connection: connectionToRemote)
        let clientStorage = InMemoryStorage()

        let subscription = await clientConnectionToRemote.subscribe(clientStorage)

        let path = ["a", "b"]
        let now = Timestamp.current()
        await subscription.include(path, depth: 0).wait()

        // Wait for subscription message to be delivered
        try await Task.sleep(for: .seconds(0.1))
        #expect(await layer.numberOfMessages == 1)
        await layer.resetMessageCount()

        await remoteStorage.receive(.integer(123), for: path, at: now).wait()

        // Message should be transmitted to the client
        try await Task.sleep(for: .seconds(0.1))
        #expect(await layer.numberOfMessages == 1)
        await layer.resetMessageCount()

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
}
