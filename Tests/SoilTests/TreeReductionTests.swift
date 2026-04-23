import Foundation
import Testing
@testable import Soil

@Suite("Tree Reduction")
struct TreeReductionTests {


    @Test("Root: Include all")
    func rootIncludeFullTree() throws {
        let original = ImmutableSampleTree(
            samples: [Sample(value: Value.string("root"))],
            children: [
                "a" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("a"))],
                    children: [
                        "c" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("c"))]
                        )
                    ]),
                "b" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("b"))],
                    children: [
                        "d" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("d"))]
                        )
                    ]
                )
            ]
        )

        let rootSubscriptions = SubscriptionTree()
        rootSubscriptions.include(depth: nil)

        let reduced = try #require(rootSubscriptions.reduce(original))
        #expect(reduced.samples.count == 1)
        #expect(reduced.children.count == 2)

        let a = try #require(reduced.children["a"])
        #expect(a.samples.count == 1)
        #expect(a.children.count == 1)

        let c = try #require(a.children["c"])
        #expect(c.samples.count == 1)
        #expect(c.children.count == 0)

        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.count == 1)

        let d = try #require(b.children["d"])
        #expect(d.samples.count == 1)
        #expect(d.children.count == 0)
    }

    @Test("Root: Include 0")
    func rootIncludeOnlyRoot() throws {
        let original = ImmutableSampleTree(
            samples: [Sample(value: Value.string("root"))],
            children: [
                "a" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("a"))],
                    children: [
                        "c" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("c"))]
                        )
                    ]),
                "b" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("b"))],
                    children: [
                        "d" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("d"))]
                        )
                    ]
                )
            ]
        )

        let rootSubscriptions = SubscriptionTree()
        rootSubscriptions.include(depth: 0)

        let reduced = try #require(rootSubscriptions.reduce(original))
        #expect(reduced.samples.count == 1)
        #expect(reduced.children.count == 0)
    }

    @Test("Root: Exclude root, include rest")
    func rootExcludeRootKeepRest() throws {
        let original = ImmutableSampleTree(
            samples: [Sample(value: Value.string("root"))],
            children: [
                "a" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("a"))],
                    children: [
                        "c" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("c"))]
                        )
                    ]),
                "b" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("b"))],
                    children: [
                        "d" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("d"))]
                        )
                    ]
                )
            ]
        )

        let rootSubscriptions = SubscriptionTree()
        rootSubscriptions.include(depth: nil)
        rootSubscriptions.exclude(depth: 0)

        let reduced = try #require(rootSubscriptions.reduce(original))
        #expect(reduced.samples.count == 0)
        #expect(reduced.children.count == 2)

        let a = try #require(reduced.children["a"])
        #expect(a.samples.count == 1)
        #expect(a.children.count == 1)

        let c = try #require(a.children["c"])
        #expect(c.samples.count == 1)
        #expect(c.children.count == 0)

        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.count == 1)

        let d = try #require(b.children["d"])
        #expect(d.samples.count == 1)
        #expect(d.children.count == 0)
    }

    @Test("Root: Exclude in child")
    func rootExcludeInChild() throws {
        let original = ImmutableSampleTree(
            samples: [Sample(value: Value.string("root"))],
            children: [
                "a" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("a"))],
                    children: [
                        "c" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("c"))]
                        )
                    ]),
                "b" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("b"))],
                    children: [
                        "d" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("d"))]
                        )
                    ]
                )
            ]
        )

        let rootSubscriptions = SubscriptionTree()
        rootSubscriptions.include(depth: nil)

        let aSubscriptions = rootSubscriptions.createChild(named: "a")
        aSubscriptions.exclude(depth: nil)

        let reduced = try #require(rootSubscriptions.reduce(original))
        #expect(reduced.samples.count == 1)
        #expect(reduced.children.count == 1)

        #expect(reduced.children["a"] == nil)

        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.count == 1)

        let d = try #require(b.children["d"])
        #expect(d.samples.count == 1)
        #expect(d.children.count == 0)
    }

    @Test("Root: Exclude only child, keep sub")
    func rootExcludeInChildKeepSub() throws {
        let original = ImmutableSampleTree(
            samples: [Sample(value: Value.string("root"))],
            children: [
                "a" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("a"))],
                    children: [
                        "c" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("c"))]
                        )
                    ]),
                "b" : ImmutableSampleTree(
                    samples: [Sample(value: Value.string("b"))],
                    children: [
                        "d" : ImmutableSampleTree(
                            samples: [Sample(value: Value.string("d"))]
                        )
                    ]
                )
            ]
        )

        let rootSubscriptions = SubscriptionTree()
        rootSubscriptions.include(depth: nil)

        let aSubscriptions = rootSubscriptions.createChild(named: "a")
        aSubscriptions.exclude(depth: 0)

        let reduced = try #require(rootSubscriptions.reduce(original))
        #expect(reduced.samples.count == 1)
        #expect(reduced.children.count == 2)

        let a = try #require(reduced.children["a"])
        #expect(a.samples.count == 0)
        #expect(a.children.count == 1)

        let c = try #require(a.children["c"])
        #expect(c.samples.count == 1)
        #expect(c.children.count == 0)

        let b = try #require(reduced.children["b"])
        #expect(b.samples.count == 1)
        #expect(b.children.count == 1)

        let d = try #require(b.children["d"])
        #expect(d.samples.count == 1)
        #expect(d.children.count == 0)
    }
}