
import Foundation
import Testing
@testable import Soil

@Suite("Subscriptions")
struct SubscriptionTests {

    @Test("Exact path")
    func subscribeToExactPath() async throws {
        let storage = InMemoryStorage()
        let observable = ObservableStorage(wrapping: storage)

        let receiver = InMemoryStorage()

        let subscription = await observable.subscribe(receiver)

        let path = ["a", "b"]
        let now = Timestamp.current()
        await subscription.include(path, depth: 0).wait()

        await observable.receive(.integer(123), for: path, at: now).wait()

        try await Task.sleep(for: .seconds(0.1))

        do {
            let optionalSample = await receiver.currentSample(for: path)
            let sample = try #require(optionalSample)
            #expect(sample.value == .integer(123))
            #expect(sample.isVeryClose(to: now))
        }
    }
}