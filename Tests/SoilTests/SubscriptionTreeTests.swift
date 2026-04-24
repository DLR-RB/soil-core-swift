import Foundation
import Testing
@testable import Soil

@Suite("Subscription Tree")
struct SubscriptionTreeTests {

    @Test("Exact path")
    func subscribeToExactPath() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b", "c"]

        #expect(!tree.hasSubscriptionRulesInTree)
        #expect(tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))

        tree.include(path, depth: 0)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))
    }

    @Test("Ancestor path")
    func subscribeToAncestorPath() throws {
        let tree = SubscriptionTree()

        let path = ["a", "b", "c"]

        #expect(!tree.hasSubscriptionRulesInTree)
        #expect(tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))

        tree.include(["a", "b"], depth: 1)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))
    }

    @Test("Ancestor path (no depth)")
    func subscribeToAncestorPathNoDepth() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b", "c"]

        #expect(!tree.hasSubscriptionRulesInTree)
        #expect(tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))

        tree.include(["a"], depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))
    }

    @Test("Exclude exact path")
    func excludeExactPath() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b", "c"]

        #expect(!tree.hasSubscriptionRulesInTree)
        #expect(tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))

        tree.include(["a"], depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(path, depth: 0)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))
    }

    @Test("Exclude ancestor path")
    func excludeAncestorPath() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b", "c"]

        tree.include(["a"], depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(["a", "b"], depth: 1)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))
    }

    @Test("Exclude irrelevant ancestor path")
    func excludeIrrelevantAncestorPath() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b", "c"]

        tree.include([], depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(["a"], depth: 1)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))
    }

    @Test("Override exclusion")
    func testOverrideExclusion() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b", "c"]

        tree.include([], depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(["a"], depth: 2)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))

        tree.include(path, depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))
    }

    @Test("Remove all rules")
    func testRemoveAllRules() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b"]

        tree.include(path, depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))

        tree.deleteAllRules()

        #expect(!tree.hasSubscriptionRulesInTree)
        #expect(tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))
    }

    @Test("Delete subscription rules")
    func testRemoveSubscriptionRules() throws {
        let tree = SubscriptionTree()
        let path = ["a", "b"]

        tree.include(path, depth: nil)

        #expect(tree.hasSubscriptionRulesInTree)
        #expect(!tree.isEmpty)
        #expect(tree.isSubscribed(to: path))

        tree.deleteRules(at: path, depth: nil)

        #expect(!tree.hasSubscriptionRulesInTree)
        #expect(tree.isEmpty)
        #expect(!tree.isSubscribed(to: path))
    }

    @Test("Multiple rules for path")
    func multipleRulesForPath() {
        let tree = SubscriptionTree()
        let subPath = ["a"]
        let path = ["a", "b"]

        // Create multiple rules for path "a"
        tree.include(subPath, depth: nil)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(subPath, depth: 3)
        #expect(!tree.isSubscribed(to: path))

        tree.include(subPath, depth: 2)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(subPath, depth: 2)
        #expect(!tree.isSubscribed(to: path))

        tree.include(subPath, depth: 1)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(subPath, depth: 1)
        #expect(!tree.isSubscribed(to: path))

        // Does not match the path
        tree.include(subPath, depth: 0)
        #expect(!tree.isSubscribed(to: path))

        // Add rules for the exact path, which should override previous ones
        tree.include(path, depth: nil)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(path, depth: nil)
        #expect(!tree.isSubscribed(to: path))

        tree.include(path, depth: 2)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(path, depth: 2)
        #expect(!tree.isSubscribed(to: path))

        tree.include(path, depth: 1)
        #expect(tree.isSubscribed(to: path))

        tree.exclude(path, depth: 1)
        #expect(!tree.isSubscribed(to: path))

        tree.exclude(path, depth: 0)
        #expect(!tree.isSubscribed(to: path))
    }
}
