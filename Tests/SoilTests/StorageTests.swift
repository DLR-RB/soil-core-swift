import Testing
@testable import Soil

@Suite("Storage")
struct StorageTests {

    @Test("Current value for path")
    func saveAndGetValues() async {
        let storage = InMemoryStorage()

        let pathA = ["a", "b", "c"]
        let now = Timestamp.current()

        await storage.accept(.integer(123), for: pathA, at: now).wait()

        let storedPathA = await storage.currentSample(for: pathA)
        #expect(storedPathA != nil)
        #expect(storedPathA?.value == .integer(123))
        #expect(storedPathA?.timestamp == now)
    }

    /**
     Check if a sub-tree is correctly returned with all content when individual paths have been set
     */
    @Test("Get sub-tree")
    func getSubTree() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()

        await storage.accept(.integer(123), for: ["a", "b", "c"], at: now).wait()
        await storage.accept(.double(3.14), for: ["a", "b", "d"], at: now).wait()
        await storage.accept(.string("some"), for: ["a", "e"], at: now).wait()

        do {
            let tree = await storage.tree(for: ["a"], depth: nil)
            #expect(tree.newestSample == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.newestSample == nil)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .integer(123))
            #expect(cSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            let dSample = try #require(d.newestSample)
            #expect(dSample.value == .double(3.14))
            #expect(dSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(e.children.count == 0)
        }
    }

    @Test("Sub-tree with depth")
    func subTreeWithDepth() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()

        do {
            let c = ImmutableSampleTree(value: .integer(123), timestamp: now)
            let d = ImmutableSampleTree(value: .double(3.14), timestamp: now)
            let b = ImmutableSampleTree(children: ["c" : c, "d" : d])
            let e = ImmutableSampleTree(value: .string("some"), timestamp: now)
            let a = ImmutableSampleTree(children: ["b" : b, "e" : e])
            await storage.accept(a, for: ["a"]).wait()
        }

        do {
            let tree = await storage.tree(for: ["a"], depth: 2)
            #expect(tree.newestSample == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.newestSample == nil)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(c.samples.count == 1)
            #expect(cSample.value == .integer(123))
            #expect(cSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            let dSample = try #require(d.newestSample)
            #expect(d.samples.count == 1)
            #expect(dSample.value == .double(3.14))
            #expect(dSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(e.samples.count == 1)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(e.children.count == 0)
        }

        do {
            let tree = await storage.tree(for: ["a"], depth: 1)
            #expect(tree.newestSample == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.newestSample == nil)
            #expect(b.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp.isEqual(to: now, tolerance: testTimeTolerance))
            #expect(e.children.count == 0)
        }

        do {
            let tree = await storage.tree(for: ["a"], depth: 0)
            #expect(tree.newestSample == nil)
            #expect(tree.children.count == 0)
        }
    }

    @Test("Partioning")
    func testPartitioning() {
        let now = Timestamp.current()
        let later = now.addingTimeInterval(1)
        let all = [now, later]
        let index = all.partitioningIndex { $0 >= later }
        #expect(index == 1)
        #expect(all[1] == later)
    }

    @Test("History")
    func testGetHistory() async throws {
        let storage = InMemoryStorage()

        do {
            let empty = await storage.samples(for: [], from: nil, to: nil, limit: nil)
            #expect(empty.isEmpty)
        }
        do {
            let empty = await storage.samples(for: [], from: nil, to: nil, limit: 1)
            #expect(empty.isEmpty)
        }
        do {
            let empty = await storage.samples(for: [], from: .current(), to: nil, limit: nil)
            #expect(empty.isEmpty)
        }
        do {
            let empty = await storage.samples(for: [], from: nil, to: .current(), limit: nil)
            #expect(empty.isEmpty)
        }

        let first = Timestamp.current()
        await storage.accept(.integer(123), for: [], at: first).wait()
        do {
            let one = await storage.samples(for: [], from: nil, to: nil, limit: nil)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(123))
            #expect(one[0].timestamp == first)
        }
        do {
            // start date is exclusive, so no values expected
            let empty = await storage.samples(for: [], from: first, to: nil, limit: nil)
            #expect(empty.isEmpty)
        }
        do {
            // end date is inclusive, so expect the value
            let one = await storage.samples(for: [], from: nil, to: first, limit: nil)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(123))
            #expect(one[0].timestamp == first)
        }

        let second = first.addingTimeInterval(1.0)
        await storage.accept(.integer(234), for: [], at: second).wait()
        do {
            let two = await storage.samples(for: [], from: nil, to: nil, limit: nil)
            try #require(two.count == 2)
            // Values are returned oldest first
            #expect(two[0].value == .integer(123))
            #expect(two[0].timestamp == first)
            #expect(two[1].value == .integer(234))
            #expect(two[1].timestamp == second)
        }
        do {
            // start date is exclusive, so expect only second value
            let one = await storage.samples(for: [], from: first, to: nil, limit: nil)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(234))
            #expect(one[0].timestamp == second)
        }
        do {
            // end date is inclusive, so expect both values
            let two = await storage.samples(for: [], from: nil, to: second, limit: nil)
            try #require(two.count == 2)
            // Values are returned oldest first
            #expect(two[0].value == .integer(234))
            #expect(two[0].timestamp == second)
            #expect(two[1].value == .integer(123))
            #expect(two[1].timestamp == first)
        }
        do {
            // limit to 1, so only expect first value
            let one = await storage.samples(for: [], from: nil, to: nil, limit: 1)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(123))
            #expect(one[0].timestamp == first)
        }
    }

    @Test("History order")
    func testHistoryOrder() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        let samples = (0..<10).map {
            Sample(value: .integer(123 + $0), timestamp: now.addingTimeInterval(Double($0)))
        }
        for sample in samples {
            await storage.accept(sample.value, for: [], at: sample.timestamp).wait()
        }

        let history = await storage.samples(for: [])
        try #require(history.count == samples.count)
        #expect(history.first! < history.last!, "History should be sorted oldest first")
        for index in history.indices {
            let retrieved = history[index]
            let original = samples[index]
            let origTime = try #require(original.timestamp)
            #expect(retrieved.value == original.value)
            #expect(retrieved.timestamp.isEqual(to: origTime, tolerance: testTimeTolerance))
        }
    }
}
