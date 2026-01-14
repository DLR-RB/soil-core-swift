import Foundation
import Testing
@testable import Soil

@Suite("Internal Subscriptions")
struct InternalSubscriptionTests {

    @Test("Exact path")
    func subscribeToExactPath() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123

        let path = ["a", "b", "c"]
        manager.subscribe(id, to: path, depth: 0) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Ancestor path")
    func subscribeToAncestorPath() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a", "b"], depth: 1) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Ancestor path (no depth)")
    func subscribeToAncestorPathNoDepth() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a"], depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Exclude exact path")
    func excludeExactPath() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a"], depth: nil) { _, _, _ in
            #expect(Bool(false))
        }
        manager.exclude(id, from: path, depth: 0)
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Exclude ancestor path")
    func excludeAncestorPath() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a"], depth: nil) { _, _, _ in
            #expect(Bool(false))
        }
        manager.exclude(id, from: ["a", "b"], depth: 1)
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Exclude irrelevant ancestor path")
    func excludeIrrelevantAncestorPath() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: [], depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        manager.exclude(id, from: ["a"], depth: 1)
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Override exclusion")
    func testOverrideExclusion() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: [], depth: nil) { id, path, sample in
            #expect(Bool(false))
        }
        manager.exclude(id, from: ["a"], depth: 2)
        manager.subscribe(id, to: path, depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Multiple subscribers")
    func testMultipleSubscribers() throws {
        let manager = InternalSubscriptionsManager()

        let sample = Sample(value: .integer(42))
        let alice = 42
        let bob = 43

        var expectedPath: Path = []

        manager.subscribe(alice, to: ["a", "b"], depth: nil) {
            #expect($0 == alice)
            #expect($1 == expectedPath)
            #expect($2 == sample)
        }
        manager.subscribe(bob, to: ["a"], depth: nil) {
            #expect($0 == bob)
            #expect($1 == expectedPath)
            #expect($2 == sample)
        }

        #expect(manager.hasCallback(for: alice))
        #expect(manager.hasSubscriptions(for: alice))
        #expect(manager.hasCallback(for: bob))
        #expect(manager.hasSubscriptions(for: bob))

        do {
            expectedPath = ["a"]
            let subscribers = manager.subscribers(to: expectedPath)
            #expect(subscribers == [bob])

            let notified = manager.notifySubscribers(about: sample, at: expectedPath)
            #expect(notified == 1)
        }

        do {
            expectedPath = ["a", "b"]
            let subscribers = manager.subscribers(to: expectedPath)
            #expect(subscribers == [alice, bob])

            let notified = manager.notifySubscribers(about: sample, at: expectedPath)
            #expect(notified == 2)
        }

        do {
            expectedPath = ["a", "c"]
            let subscribers = manager.subscribers(to: expectedPath)
            #expect(subscribers == [bob])

            let notified = manager.notifySubscribers(about: sample, at: expectedPath)
            #expect(notified == 1)
        }
    }

    @Test("Remove subscriber")
    func testRemoveSubscribers() throws {
        let manager = InternalSubscriptionsManager()

        let alice = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]


        manager.subscribe(alice, to: path, depth: nil) { id, path, sample in
            #expect(Bool(false))
        }

        #expect(manager.hasCallback(for: alice))
        #expect(manager.hasSubscriptions(for: alice))

        manager.remove(subscriber: alice)

        #expect(!manager.hasCallback(for: alice))
        #expect(!manager.hasSubscriptions(for: alice))

        let subscribers = manager.subscribers(to: path)
        #expect(subscribers.count == 0)

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Remove subscription")
    func testRemoveSubscription() throws {
        let manager = InternalSubscriptionsManager()

        let alice = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]

        manager.subscribe(alice, to: path, depth: nil) { id, path, sample in
            #expect(Bool(false))
        }

        #expect(manager.hasCallback(for: alice))
        #expect(manager.hasSubscriptions(for: alice))

        manager.exclude(alice, from: path, depth: nil)

        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [])

        #expect(!manager.hasCallback(for: alice))
        #expect(!manager.hasSubscriptions(for: alice))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Remove exclusion")
    func testRemoveExclusion() throws {
        let manager = InternalSubscriptionsManager()

        let id = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]

        manager.exclude(id, from: path, depth: nil)

        #expect(!manager.hasCallback(for: id))
        #expect(!manager.hasSubscriptions(for: id))

        manager.subscribe(id, to: path, depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }

        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasCallback(for: id))
        #expect(manager.hasSubscriptions(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }
}
