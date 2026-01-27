import Foundation
import Testing
@testable import Soil

@Suite("Internal Subscriptions")
struct InternalSubscriptionTests {

    @Test("Exact path")
    func subscribeToExactPath() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123

        let path = ["a", "b", "c"]
        manager.subscribe(id, to: path, depth: 0) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }

        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Ancestor path")
    func subscribeToAncestorPath() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a", "b"], depth: 1) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Ancestor path (no depth)")
    func subscribeToAncestorPathNoDepth() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a"], depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Exclude exact path")
    func excludeExactPath() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a"], depth: nil) { _, _, _ in
            #expect(Bool(false))
        }
        manager.exclude(path, depth: 0, from: id)

        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Exclude ancestor path")
    func excludeAncestorPath() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: ["a"], depth: nil) { _, _, _ in
            #expect(Bool(false))
        }
        manager.exclude(["a", "b"], depth: 1, from: id)
        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Exclude irrelevant ancestor path")
    func excludeIrrelevantAncestorPath() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: [], depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        manager.exclude(["a"], depth: 1, from: id)
        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Override exclusion")
    func testOverrideExclusion() throws {
        let manager = ComponentSubscriptions()

        let sample = Sample(value: .integer(42))
        let id = 123
        let path = ["a", "b", "c"]

        manager.subscribe(id, to: [], depth: nil) { id, path, sample in
            #expect(Bool(false))
        }
        manager.exclude(["a"], depth: 2, from: id)
        manager.subscribe(id, to: path, depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }
        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Multiple subscribers")
    func testMultipleSubscribers() throws {
        let manager = ComponentSubscriptions()

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

        #expect(manager.hasSubscription(alice))
        #expect(manager.hasSubscriptionRules(for: alice))
        #expect(manager.hasSubscription(bob))
        #expect(manager.hasSubscriptionRules(for: bob))

        do {
            expectedPath = ["a"]
            let subscribers = manager.subscriptions(to: expectedPath)
            #expect(subscribers == [bob])

            let notified = manager.notifySubscribers(about: sample, at: expectedPath)
            #expect(notified == 1)
        }

        do {
            expectedPath = ["a", "b"]
            let subscribers = manager.subscriptions(to: expectedPath)
            #expect(subscribers == [alice, bob])

            let notified = manager.notifySubscribers(about: sample, at: expectedPath)
            #expect(notified == 2)
        }

        do {
            expectedPath = ["a", "c"]
            let subscribers = manager.subscriptions(to: expectedPath)
            #expect(subscribers == [bob])

            let notified = manager.notifySubscribers(about: sample, at: expectedPath)
            #expect(notified == 1)
        }
    }

    @Test("Remove subscriber")
    func testRemoveSubscribers() throws {
        let manager = ComponentSubscriptions()

        let alice = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]


        manager.subscribe(alice, to: path, depth: nil) { id, path, sample in
            #expect(Bool(false))
        }

        #expect(manager.hasSubscription(alice))
        #expect(manager.hasSubscriptionRules(for: alice))

        manager.delete(subscription: alice)

        #expect(!manager.hasSubscription(alice))
        #expect(!manager.hasSubscriptionRules(for: alice))

        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers.count == 0)

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Delete subscription rules")
    func testRemoveSubscription() throws {
        let manager = ComponentSubscriptions()

        let alice = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]

        manager.subscribe(alice, to: path, depth: nil) { id, path, sample in
            #expect(Bool(false))
        }

        #expect(manager.hasSubscription(alice))
        #expect(manager.hasSubscriptionRules(for: alice))

        manager.deleteRules(at: path, depth: nil, for: alice)

        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [])

        #expect(manager.hasSubscription(alice))
        #expect(!manager.hasSubscriptionRules(for: alice))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Delete subscription")
    func testDeleteSubscription() {
        let manager = ComponentSubscriptions()

        let alice = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]

        manager.subscribe(alice, to: path, depth: nil) { id, path, sample in
            #expect(Bool(false))
        }

        #expect(manager.hasSubscription(alice))
        #expect(manager.hasSubscriptionRules(for: alice))

        manager.delete(subscription: alice)

        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [])

        #expect(!manager.hasSubscription(alice))
        #expect(!manager.hasSubscriptionRules(for: alice))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 0)
    }

    @Test("Remove exclusion")
    func testRemoveExclusion() throws {
        let manager = ComponentSubscriptions()

        let id = 42
        let sample = Sample(value: .integer(42))
        let path = ["a", "b"]

        manager.exclude(path, depth: nil, from: id)

        #expect(!manager.hasSubscription(id))
        #expect(!manager.hasSubscriptionRules(for: id))

        manager.subscribe(id, to: path, depth: nil) {
            #expect($0 == id)
            #expect($1 == path)
            #expect($2 == sample)
        }

        let subscribers = manager.subscriptions(to: path)
        #expect(subscribers == [id])

        #expect(manager.hasSubscription(id))
        #expect(manager.hasSubscriptionRules(for: id))

        let notified = manager.notifySubscribers(about: sample, at: path)
        #expect(notified == 1)
    }

    @Test("Multiple rules for path")
    func multipleRulesForPath() {
        let manager = ComponentSubscriptions()

        let subscription = 42
        let sample = Sample(value: .integer(42))
        let subPath = ["a"]
        let path = ["a", "b"]

        manager.create(subscription) {
            #expect($0 == subscription)
            #expect($1 == path)
            #expect($2 == sample)
        }

        // Create multiple rules for path "a"
        manager.include(subPath, depth: nil, in: subscription)
        #expect(manager.subscriptions(to: path) == [subscription])

        manager.exclude(subPath, depth: 3, from: subscription)
        #expect(manager.subscriptions(to: path) == [])

        manager.include(subPath, depth: 2, in: subscription)
        #expect(manager.subscriptions(to: path) == [subscription])

        manager.exclude(subPath, depth: 2, from: subscription)
        #expect(manager.subscriptions(to: path) == [])

        manager.include(subPath, depth: 1, in: subscription)
        #expect(manager.subscriptions(to: path) == [subscription])

        manager.exclude(subPath, depth: 1, from: subscription)
        #expect(manager.subscriptions(to: path) == [])

        // Does not match the path
        manager.include(subPath, depth: 0, in: subscription)
        #expect(manager.subscriptions(to: path) == [])

        // Add rules for the exact path, which should override previous ones
        manager.include(path, depth: nil, in: subscription)
        #expect(manager.subscriptions(to: path) == [subscription])

        manager.exclude(path, depth: nil, from: subscription)
        #expect(manager.subscriptions(to: path) == [])

        manager.include(path, depth: 2, in: subscription)
        #expect(manager.subscriptions(to: path) == [subscription])

        manager.exclude(path, depth: 2, from: subscription)
        #expect(manager.subscriptions(to: path) == [])

        manager.include(path, depth: 1, in: subscription)
        #expect(manager.subscriptions(to: path) == [subscription])

        manager.exclude(path, depth: 1, from: subscription)
        #expect(manager.subscriptions(to: path) == [])

        manager.exclude(path, depth: 0, from: subscription)
        #expect(manager.subscriptions(to: path) == [])
    }
}
