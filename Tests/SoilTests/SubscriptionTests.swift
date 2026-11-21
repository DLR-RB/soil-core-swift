
import Foundation
import Testing
@testable import Soil

@Suite("Subscriptions")
struct SubscriptionTests {

    @Test("Exact path")
    func subscribeToExactPath() async throws {
        let storage = InMemoryStorage()
        let observable = ObservingStorage(wrapping: storage)

        let receiver = InMemoryStorage()

        await observable.setReceiver(receiver).wait()

        let path = ["a", "b"]
        let now = Timestamp.current()
        await observable.include(path, depth: 0).wait()

        await observable.accept(.integer(123), for: path, at: now).wait()

        try await Task.sleep(for: .seconds(0.1))

        do {
            let optionalSample = await receiver.currentSample(for: path)
            let sample = try #require(optionalSample)
            #expect(sample.value == .integer(123))
            #expect(sample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
        }
    }
}