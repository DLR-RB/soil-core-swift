import Testing
import Foundation
import Soil


@Suite("HostedObservable")
class HostedObservableTests {

    /**
     Create a hosted observable wrapping an in-memory observing storage,
     connected to a recording connection that can inject messages.
     */
    private func makeHosted() async -> (hosted: HostedObservable, storage: ObservingStorage, connection: RecordingMessageConnection) {
        let storage = ObservingStorage(wrapping: InMemoryStorage())
        let connection = RecordingMessageConnection()
        let hosted = await HostedObservable(hosting: storage, through: connection)
        return (hosted, storage, connection)
    }

    /**
     Wait for subscription changes to be applied.

     The hosted observable does not wait for the subscription requests
     forwarded to the wrapped observable, so a short delay is needed.
     */
    private func settle() async throws {
        try await Task.sleep(for: .seconds(0.05))
    }

    @Test("Remote exclusion is applied on the host")
    func testRemoteExclusion() async throws {
        let connection = await BidirectionalConnection()

        let hostStorage = ObservingStorage(wrapping: InMemoryStorage())
        let connectionToClient = await DecodedConnection(wrapping: connection.one, encoding: JsonEncoding())
        let hosted = await HostedObservableStorage(host: hostStorage, through: connectionToClient)

        let connectionToHost = await DecodedConnection(wrapping: connection.two, encoding: JsonEncoding())
        let remote = await RemoteObservableStorage(connection: connectionToHost)

        await remote.include(["a"], depth: nil).wait()
        await remote.exclude(["a", "b"], depth: nil).wait()
        try await Task.sleep(for: .seconds(0.1))

        // The client's local rules are correct
        #expect(await remote.isSubscribed(to: ["a", "c"]))
        #expect(await !remote.isSubscribed(to: ["a", "b"]))

        // The host's rules should match, but ["a", "b"] is still subscribed
        #expect(await hostStorage.isSubscribed(to: ["a", "c"]))
        #expect(await !hostStorage.isSubscribed(to: ["a", "b"]))

        _ = hosted
    }

    @Test("Remote rule deletion is applied on the host")
    func testRemoteRuleDeletion() async throws {
        // Counterpart to the exclusion test: The original bug swapped exclusion and deletion,
        // so this end-to-end test ensures that a deletion sent by the remote
        // removes the rules on the host, instead of adding an exclusion.
        let connection = await BidirectionalConnection()

        let hostStorage = ObservingStorage(wrapping: InMemoryStorage())
        let connectionToClient = await DecodedConnection(wrapping: connection.one, encoding: JsonEncoding())
        let hosted = await HostedObservableStorage(host: hostStorage, through: connectionToClient)

        let connectionToHost = await DecodedConnection(wrapping: connection.two, encoding: JsonEncoding())
        let remote = await RemoteObservableStorage(connection: connectionToHost)

        await remote.include(["a"], depth: nil).wait()
        await remote.exclude(["a", "b"], depth: nil).wait()
        await remote.deleteRules(at: ["a", "b"], depth: nil).wait()
        try await Task.sleep(for: .seconds(0.1))

        // Deleting the exclusion makes the path subscribed again through the inclusion at ["a"]
        #expect(await remote.isSubscribed(to: ["a", "b"]))
        #expect(await hostStorage.isSubscribed(to: ["a", "b"]))

        _ = hosted
    }

    @Test("Initialization registers the hosted observable as receiver")
    func testReceiverRegistration() async throws {
        // The hosted observable must receive messages from the connection (subscription requests)
        // and data from the observable (subscription updates), so both need to point to it after init.
        let (hosted, storage, connection) = await makeHosted()

        let connectionReceiver = await connection.getReceiver()
        #expect(connectionReceiver === hosted)

        let storageReceiver = await storage.getReceiver() as? HostedObservable
        #expect(storageReceiver === hosted)
    }

    @Test("Connection property exposes the hosting connection")
    func testConnectionProperty() async throws {
        // The public connection property should be the same connection passed during init.
        let (hosted, _, connection) = await makeHosted()
        let hostedConnection = await hosted.connection as? RecordingMessageConnection
        #expect(hostedConnection === connection)
    }

    @Test("Inclusion message adds a subscription")
    func testInclusionMessage() async throws {
        // An inclusion received over the connection must be forwarded to the observable as an inclusion.
        let (hosted, storage, connection) = await makeHosted()

        #expect(await !storage.isSubscribed(to: ["a"]))

        await connection.receive(.include(["a"]))
        try await settle()

        #expect(await storage.isSubscribed(to: ["a"]))
        #expect(await storage.isSubscribed(to: ["a", "b"]))
        #expect(await !storage.isSubscribed(to: ["c"]))

        _ = hosted
    }

    @Test("Exclusion message excludes a path")
    func testExclusionMessage() async throws {
        // Direct regression test for the swapped cases:
        // An exclusion must be applied as an exclusion, not as a rule deletion.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"]))
        await connection.receive(.exclude(["a", "b"]))
        try await settle()

        #expect(await storage.isSubscribed(to: ["a"]))
        #expect(await storage.isSubscribed(to: ["a", "c"]))
        #expect(await !storage.isSubscribed(to: ["a", "b"]))
        #expect(await !storage.isSubscribed(to: ["a", "b", "c"]))

        _ = hosted
    }

    @Test("Deletion message removes subscription rules")
    func testDeletionMessage() async throws {
        // Direct regression test for the swapped cases:
        // A rule deletion must remove existing rules, not add an exclusion.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"]))
        try await settle()
        #expect(await storage.isSubscribed(to: ["a"]))

        await connection.receive(.deleteRules(at: ["a"]))
        try await settle()
        #expect(await !storage.isSubscribed(to: ["a"]))

        _ = hosted
    }

    @Test("Deleting an exclusion restores the inclusion")
    func testDeletionOfExclusion() async throws {
        // Deleting the rules at an excluded path should only remove the exclusion,
        // so that the parent inclusion applies again.
        // With the swapped cases, the deletion would have been treated as an exclusion,
        // and the path would remain unsubscribed.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"]))
        await connection.receive(.exclude(["a", "b"]))
        try await settle()
        #expect(await !storage.isSubscribed(to: ["a", "b"]))

        await connection.receive(.deleteRules(at: ["a", "b"]))
        try await settle()
        #expect(await storage.isSubscribed(to: ["a", "b"]))

        _ = hosted
    }

    @Test("Subscription depth is forwarded")
    func testSubscriptionDepth() async throws {
        // The depth contained in subscription messages must be passed to the observable,
        // otherwise the host would subscribe to the full sub-tree.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"], depth: 1))
        try await settle()

        #expect(await storage.isSubscribed(to: ["a"]))
        #expect(await storage.isSubscribed(to: ["a", "b"]))
        #expect(await !storage.isSubscribed(to: ["a", "b", "c"]))

        _ = hosted
    }

    @Test("Data, request and deletion messages are ignored")
    func testNonSubscriptionMessagesIgnored() async throws {
        // The hosted observable only handles subscriptions.
        // Data, history requests, and deletion requests must not modify the storage
        // or the subscriptions, and must not produce responses.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.value(.integer(1), for: ["a"]))
        await connection.receive(.request(["a"]))
        await connection.receive(.delete(["a"]))
        try await settle()

        #expect(await storage.samples(for: ["a"]).isEmpty)
        #expect(await !storage.isSubscribed(to: ["a"]))
        #expect(await connection.sentMessages.isEmpty)

        _ = hosted
    }

    @Test("Deletion requests do not remove existing data")
    func testDeletionRequestIgnored() async throws {
        // A deletion request is a storage operation, which is not handled by the hosted observable.
        // Existing data in the wrapped storage must remain untouched.
        let (hosted, storage, connection) = await makeHosted()

        await storage.accept(.integer(1), for: ["a"]).wait()
        await connection.receive(.delete(["a"]))
        try await settle()

        #expect(await storage.currentSample(for: ["a"])?.value == .integer(1))

        _ = hosted
    }

    @Test("Subscribed data is sent over the connection")
    func testSubscribedDataIsSent() async throws {
        // When the wrapped observable produces data matching a subscription,
        // the hosted observable must forward it as a data message to the remote.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"]))
        try await settle()

        await storage.accept(.integer(42), for: ["a", "b"]).wait()

        let messages = await connection.sentMessages
        #expect(messages.count == 1)
        let message = try #require(messages.first)
        #expect(message.type == .data)
        #expect(message.path == ["a", "b"])
        #expect(message.data.currentValue == .integer(42))

        _ = hosted
    }

    @Test("Unsubscribed data is not sent over the connection")
    func testUnsubscribedDataIsNotSent() async throws {
        // Data outside of the subscription, or inside an excluded path,
        // must not be transmitted to the remote.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"]))
        await connection.receive(.exclude(["a", "b"]))
        try await settle()

        await storage.accept(.integer(1), for: ["c"]).wait()
        await storage.accept(.integer(2), for: ["a", "b"]).wait()

        #expect(await connection.sentMessages.isEmpty)

        _ = hosted
    }

    @Test("Data stops after the subscription is deleted")
    func testNoDataAfterDeletion() async throws {
        // After the remote removes its subscription rules,
        // the host should no longer forward any data for that path.
        let (hosted, storage, connection) = await makeHosted()

        await connection.receive(.include(["a"]))
        try await settle()

        await storage.accept(.integer(1), for: ["a"]).wait()
        #expect(await connection.sentMessages.count == 1)
        await connection.resetMessages()

        await connection.receive(.deleteRules(at: ["a"]))
        try await settle()

        await storage.accept(.integer(2), for: ["a"]).wait()
        #expect(await connection.sentMessages.isEmpty)

        _ = hosted
    }

    @Test("Received trees are forwarded to the connection")
    func testAcceptForwardsToConnection() async throws {
        // The Receiver conformance should pass trees directly to the connection,
        // since the subscription filtering was already done by the observable.
        let (hosted, _, connection) = await makeHosted()

        let tree = ImmutableSampleTree(value: .string("x"), timestamp: nil)
        await hosted.accept(tree, for: ["p"]).wait()

        let messages = await connection.sentMessages
        #expect(messages.count == 1)
        let message = try #require(messages.first)
        #expect(message.type == .data)
        #expect(message.path == ["p"])
        #expect(message.data.isEqual(to: tree))
    }

    @Test("Subscribed data reaches the remote end-to-end")
    func testEndToEndDataDelivery() async throws {
        // Full round trip: The remote subscribes, the host receives a value,
        // and the remote's receiver gets the update through the encoded connection.
        let connection = await BidirectionalConnection()

        let hostStorage = ObservingStorage(wrapping: InMemoryStorage())
        let connectionToClient = await DecodedConnection(wrapping: connection.one, encoding: JsonEncoding())
        let hosted = await HostedObservable(hosting: hostStorage, through: connectionToClient)

        let connectionToHost = await DecodedConnection(wrapping: connection.two, encoding: JsonEncoding())
        let remote = await RemoteObservable(connection: connectionToHost)
        let received = ObservingStorage(wrapping: InMemoryStorage())
        await remote.setReceiver(received).wait()

        await remote.include(["a"], depth: nil).wait()
        await remote.exclude(["a", "b"], depth: nil).wait()
        try await Task.sleep(for: .seconds(0.1))

        await hostStorage.accept(.integer(1), for: ["a", "c"]).wait()
        await hostStorage.accept(.integer(2), for: ["a", "b"]).wait()
        try await Task.sleep(for: .seconds(0.1))

        // Only the value at the subscribed path is delivered
        #expect(await received.currentSample(for: ["a", "c"])?.value == .integer(1))
        #expect(await received.currentSample(for: ["a", "b"]) == nil)

        _ = hosted
    }
}
