import Foundation
import Testing
@testable import Soil

@Suite("Subscription Tree")
struct SubscriptionTreeTests {

    @Test("Exact path")
    func subscribeToExactPath() throws {
        let tree = SubscriptionTree()
        let path: Path = ["a", "b", "c"]

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

        let path: Path = ["a", "b", "c"]

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
        let path: Path = ["a", "b", "c"]

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
        let path: Path = ["a", "b", "c"]

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
        let path: Path = ["a", "b", "c"]

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
        let path: Path = ["a", "b", "c"]

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
        let path: Path = ["a", "b", "c"]

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
        let path: Path = ["a", "b"]

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
        let path: Path = ["a", "b"]

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
        let subPath: Path = ["a"]
        let path: Path = ["a", "b"]

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

    // MARK: Rule bookkeeping

    @Test("Rule counts")
    func ruleCounts() {
        let tree = SubscriptionTree()
        #expect(tree.numberOfRules == 0)
        #expect(tree.totalNumberOfRules == 0)
        #expect(tree.numberOfNodes == 1)

        tree.include([], depth: nil)
        tree.include(["a"], depth: 1)
        tree.exclude(["a", "b"], depth: 0)
        tree.include(["a", "b", "c"], depth: 2)

        #expect(tree.numberOfRules == 1)
        #expect(tree.totalNumberOfRules == 4)
        #expect(tree.numberOfNodes == 4)
    }

    @Test("Duplicate rules are ignored")
    func duplicateRules() {
        let tree = SubscriptionTree()
        tree.include(["a"], depth: 1)
        tree.include(["a"], depth: 1)
        tree.exclude(["a"], depth: 2)
        tree.exclude(["a"], depth: 2)
        #expect(tree.totalNumberOfRules == 2)
    }

    @Test("Opposite rule with same depth replaces rule")
    func oppositeRuleReplaces() {
        let tree = SubscriptionTree()
        let path: Path = ["a"]

        tree.include(path, depth: nil)
        tree.exclude(path, depth: nil)
        #expect(tree.totalNumberOfRules == 1)
        #expect(!tree.isSubscribed(to: path))

        tree.include(path, depth: nil)
        #expect(tree.totalNumberOfRules == 1)
        #expect(tree.isSubscribed(to: path))
    }

    // MARK: Depth handling

    @Test("Inclusion depth limits")
    func inclusionDepthLimits() {
        let tree = SubscriptionTree()
        tree.include(["a"], depth: 1)

        #expect(!tree.isSubscribed(to: []))
        #expect(tree.isSubscribed(to: ["a"]))
        #expect(tree.isSubscribed(to: ["a", "b"]))
        #expect(!tree.isSubscribed(to: ["a", "b", "c"]))
        #expect(!tree.isSubscribed(to: ["x"]))
        #expect(!tree.isSubscribed(to: ["x", "b"]))
    }

    @Test("Root inclusion with depth")
    func rootInclusionDepth() {
        let tree = SubscriptionTree()
        tree.include([], depth: 2)

        #expect(tree.isSubscribed(to: []))
        #expect(tree.isSubscribed(to: ["a"]))
        #expect(tree.isSubscribed(to: ["a", "b"]))
        #expect(!tree.isSubscribed(to: ["a", "b", "c"]))
    }

    @Test("Rule on sibling does not affect path")
    func siblingRule() {
        let tree = SubscriptionTree()
        tree.include([], depth: nil)
        tree.exclude(["a", "x"], depth: nil)

        #expect(tree.isSubscribed(to: ["a", "b"]))
        #expect(!tree.isSubscribed(to: ["a", "x"]))
        #expect(!tree.isSubscribed(to: ["a", "x", "y"]))
    }

    @Test("Smaller depth wins at the same node")
    func smallerDepthWins() {
        let tree = SubscriptionTree()
        tree.exclude(["a"], depth: 1)
        tree.include(["a"], depth: 3)

        #expect(!tree.isSubscribed(to: ["a"]))
        #expect(!tree.isSubscribed(to: ["a", "b"]))
        #expect(tree.isSubscribed(to: ["a", "b", "c"]))
        #expect(tree.isSubscribed(to: ["a", "b", "c", "d"]))
        #expect(!tree.isSubscribed(to: ["a", "b", "c", "d", "e"]))
    }

    // MARK: Deletion

    @Test("Delete rules keeps other branches")
    func deleteRulesKeepsOtherBranches() {
        let tree = SubscriptionTree()
        tree.include(["a", "b"], depth: nil)
        tree.include(["a", "c"], depth: nil)

        tree.deleteRules(at: ["a", "b"], depth: nil)

        #expect(!tree.isSubscribed(to: ["a", "b"]))
        #expect(tree.isSubscribed(to: ["a", "c"]))
        #expect(tree.existingNode(for: ["a", "b"]) == nil)
        #expect(tree.existingNode(for: ["a", "c"]) != nil)
        #expect(tree.numberOfNodes == 3)
    }

    @Test("Delete rules with depth keeps deeper rules")
    func deleteRulesWithDepth() {
        let tree = SubscriptionTree()
        tree.include(["a"], depth: nil)
        tree.include(["a", "b"], depth: nil)
        tree.include(["a", "b", "c"], depth: nil)

        tree.deleteRules(at: ["a"], depth: 1)

        #expect(tree.totalNumberOfRules == 1)
        #expect(!tree.isSubscribed(to: ["a"]))
        #expect(!tree.isSubscribed(to: ["a", "b"]))
        #expect(tree.isSubscribed(to: ["a", "b", "c"]))
        #expect(tree.existingNode(for: ["a", "b", "c"]) != nil)
    }

    @Test("Delete rules on non-existing path")
    func deleteRulesMissingPath() {
        let tree = SubscriptionTree()
        tree.include(["a"], depth: nil)

        tree.deleteRules(at: ["x", "y"], depth: nil)

        #expect(tree.totalNumberOfRules == 1)
        #expect(tree.isSubscribed(to: ["a"]))
    }

    @Test("Delete rules keeps ancestors with rules")
    func deleteRulesKeepsAncestorsWithRules() {
        let tree = SubscriptionTree()
        tree.include(["a"], depth: 0)
        tree.include(["a", "b", "c"], depth: nil)

        tree.deleteRules(at: ["a", "b", "c"], depth: nil)

        #expect(tree.existingNode(for: ["a", "b"]) == nil)
        #expect(tree.existingNode(for: ["a"]) != nil)
        #expect(tree.isSubscribed(to: ["a"]))
        #expect(tree.numberOfNodes == 2)
    }

    // MARK: Reduction

    private func sampleTree() -> ImmutableSampleTree {
        ImmutableSampleTree(
            value: .string("a"),
            children: [
                "b": ImmutableSampleTree(
                    value: .string("b"),
                    children: [
                        "c": ImmutableSampleTree(
                            value: .string("c"),
                            children: [
                                "d": ImmutableSampleTree(value: .string("d"))
                            ])
                    ]),
                "x": ImmutableSampleTree(value: .string("x"))
            ])
    }

    @Test("Reduce respects depth below nodes without rules")
    func reduceDepthBelowNodesWithoutRules() throws {
        let tree = SubscriptionTree()
        tree.include([], depth: 1)

        let reduced = try #require(tree.reduce(sampleTree(), for: []))
        #expect(reduced.samples.count == 1)
        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.isEmpty)
        #expect(reduced.children["x"] != nil)
    }

    @Test("Reduce at sub path uses root rule depth")
    func reduceAtSubPathRootDepth() throws {
        let tree = SubscriptionTree()
        tree.include([], depth: 2)

        // The tree is located at path "a", so "a" and "b" are included
        let reduced = try #require(tree.reduce(sampleTree(), for: ["a"]))
        #expect(reduced.samples.count == 1)
        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.isEmpty)
        #expect(reduced.children["x"] != nil)
    }

    @Test("Reduce at path with existing rule node")
    func reduceAtExistingNode() throws {
        let tree = SubscriptionTree()
        tree.include([], depth: 2)
        tree.exclude(["a", "x"], depth: nil)

        let reduced = try #require(tree.reduce(sampleTree(), for: ["a"]))
        #expect(reduced.samples.count == 1)
        #expect(reduced.children["x"] == nil)
        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.isEmpty)
    }

    @Test("Reduce at path below inclusion")
    func reduceBelowInclusion() throws {
        let tree = SubscriptionTree()
        tree.include(["p"], depth: 2)

        // Tree located at "p/a": "a" is depth 1, "b" depth 2, "c" depth 3
        let reduced = try #require(tree.reduce(sampleTree(), for: ["p", "a"]))
        #expect(reduced.samples.count == 1)
        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.isEmpty)
    }

    @Test("Reduce without matching rules")
    func reduceWithoutRules() {
        let tree = SubscriptionTree()
        tree.include(["other"], depth: nil)
        #expect(tree.reduce(sampleTree(), for: ["a"]) == nil)
    }

    @Test("Reduce matches isSubscribed")
    func reduceMatchesIsSubscribed() {
        let tree = SubscriptionTree()
        tree.include([], depth: 3)
        tree.exclude(["a", "b"], depth: 0)
        tree.include(["a", "b", "c"], depth: nil)
        tree.exclude(["a", "x"], depth: nil)

        let reduced = tree.reduce(sampleTree(), for: ["a"])

        func check(_ node: (any SampleTree)?, original: any SampleTree, path: Path) {
            let hasSamples = !(node?.samples.isEmpty ?? true)
            #expect(hasSamples == tree.isSubscribed(to: path), "Mismatch at \(path)")
            for (name, child) in original.children {
                check(node?.children[name], original: child, path: Path(path.components + [name]))
            }
        }
        check(reduced, original: sampleTree(), path: ["a"])
    }
}
