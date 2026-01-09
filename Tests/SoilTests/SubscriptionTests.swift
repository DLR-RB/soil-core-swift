import Foundation
import Testing
@testable import Soil

@Suite("Subscriptions")
struct SubscriptionTests {

    @Test("Exact path")
    func subscribeToExactPath() throws {
        let manager = SubscriptionManager<String>()

        let path = ["a", "b", "c"]
        manager.subscribe("subscriber", to: path, depth: 0)
        let subscribers = manager.subscribers(to: path)
        #expect(subscribers == ["subscriber"])
    }

    @Test("Ancestor path")
    func subscribeToAncestorPath() throws {
        let manager = SubscriptionManager<String>()

        manager.subscribe("subscriber", to: ["a", "b"], depth: 1)
        let subscribers = manager.subscribers(to: ["a", "b", "c"])
        #expect(subscribers == ["subscriber"])
    }

    @Test("Ancestor path (no depth)")
    func subscribeToAncestorPathNoDepth() throws {
        let manager = SubscriptionManager<String>()

        manager.subscribe("subscriber", to: ["a"], depth: nil)
        let subscribers = manager.subscribers(to: ["a", "b", "c"])
        try #require(subscribers.count == 1)
        let subscriber = try #require(subscribers.first)
        #expect(subscriber == "subscriber")
    }

    @Test("Exclude exact path")
    func excludeExactPath() throws {
        let manager = SubscriptionManager<String>()

        let name = "subscriber"

        manager.subscribe(name, to: ["a"], depth: nil)
        manager.exclude(name, from: ["a", "b", "c"], depth: 0)
        let subscribers = manager.subscribers(to: ["a", "b", "c"])
        #expect(subscribers == [])
    }

    @Test("Exclude ancestor path")
    func excludeAncestorPath() throws {
        let manager = SubscriptionManager<String>()

        let name = "subscriber"

        manager.subscribe(name, to: ["a"], depth: nil)
        manager.exclude(name, from: ["a", "b"], depth: 1)
        let subscribers = manager.subscribers(to: ["a", "b", "c"])
        #expect(subscribers == [])
    }

    @Test("Exclude irrelevant ancestor path")
    func excludeIrrelevantAncestorPath() throws {
        let manager = SubscriptionManager<String>()

        let name = "subscriber"

        manager.subscribe(name, to: [], depth: nil)
        manager.exclude(name, from: ["a"], depth: 1)
        let subscribers = manager.subscribers(to: ["a", "b", "c"])
        #expect(subscribers == [name])
    }

    @Test("Override exclusion")
    func testOverrideExclusion() throws {
        let manager = SubscriptionManager<String>()

        let name = "subscriber"

        manager.subscribe(name, to: [], depth: nil)
        manager.exclude(name, from: ["a"], depth: 2)
        manager.subscribe(name, to: ["a", "b", "c"], depth: nil)
        let subscribers = manager.subscribers(to: ["a", "b", "c"])
        #expect(subscribers == [name])
    }

    @Test("Multiple subscribers")
    func testMultipleSubscribers() throws {
        let manager = SubscriptionManager<String>()

        let alice = "a"
        let bob = "b"

        manager.subscribe(alice, to: ["a", "b"], depth: nil)
        manager.subscribe(bob, to: ["a"], depth: nil)
        do {
            let subscribers = manager.subscribers(to: ["a"])
            #expect(subscribers == [bob])
        }

        do {
            let subscribers = manager.subscribers(to: ["a", "b"])
            #expect(subscribers == [alice, bob])
        }

        do {
            let subscribers = manager.subscribers(to: ["a", "c"])
            #expect(subscribers == [bob])
        }
    }

    @Test("Remove subscriber")
    func testRemoveSubscribers() throws {
        let manager = SubscriptionManager<String>()

        let alice = "a"

        manager.subscribe(alice, to: ["a", "b"], depth: nil)
        manager.remove(subscriber: alice)

        do {
            let subscribers = manager.subscribers(to: ["a", "b"])
            #expect(subscribers.count == 0)
        }
    }

    @Test("Remove subscription")
    func testRemoveSubscription() throws {
        let manager = SubscriptionManager<String>()

        let alice = "a"


        manager.subscribe(alice, to: ["a", "b"], depth: nil)
        manager.exclude(alice, from: ["a", "b"], depth: nil)

        do {
            let subscribers = manager.subscribers(to: ["a", "b"])
            #expect(subscribers == [])
        }
    }

    @Test("Remove exclusion")
    func testRemoveExclusion() throws {
        let manager = SubscriptionManager<String>()

        let alice = "a"

        manager.exclude(alice, from: ["a", "b"], depth: nil)
        manager.subscribe(alice, to: ["a", "b"], depth: nil)

        do {
            let subscribers = manager.subscribers(to: ["a", "b"])
            #expect(subscribers == [alice])
        }
    }
}
