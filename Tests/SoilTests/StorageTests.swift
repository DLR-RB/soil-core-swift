import Foundation
import Testing
import Soil

@Suite("Storage")
struct StorageTests {

    @Test("Current value for path")
    func saveAndGetValues() throws {
        let storage = InMemoryStorage()

        let pathA = ["a", "b", "c"]
        let now = Date()

        storage.save(.integer(123), for: pathA, at: now)

        let storedPathA = storage.sample(for: pathA)
        #expect(storedPathA != nil)
        #expect(storedPathA?.value == .integer(123))
        #expect(storedPathA?.timestamp == now)
    }

    /**
     Check if a sub-tree is correctly returned with all content when individual paths have been set
     */
    @Test("Get sub-tree")
    func getSubTree() throws {
        let storage = InMemoryStorage()

        let now = Date()

        storage.save(.integer(123), for: ["a", "b", "c"], at: now)
        storage.save(.double(3.14), for: ["a", "b", "d"], at: now)
        storage.save(.string("some"), for: ["a", "e"], at: now)

        do {
            let tree = storage.tree(for: ["a"], depth: nil)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            #expect(c.value == .integer(123))
            #expect(c.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            #expect(d.value == .double(3.14))
            #expect(d.timestamp?.isVeryClose(to: now) ?? false)
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.value == .string("some"))
            #expect(e.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.count == 0)
        }
    }

    @Test("Sub-tree with depth")
    func subTreeWithDepth() throws {
        let storage = InMemoryStorage()

        let now = Date()

        storage.save(.integer(123), for: ["a", "b", "c"], at: now)
        storage.save(.double(3.14), for: ["a", "b", "d"], at: now)
        storage.save(.string("some"), for: ["a", "e"], at: now)

        do {
            let tree = storage.tree(for: ["a"], depth: 2)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            #expect(c.value == .integer(123))
            #expect(c.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            #expect(d.value == .double(3.14))
            #expect(d.timestamp?.isVeryClose(to: now) ?? false)
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.value == .string("some"))
            #expect(e.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.count == 0)
        }

        do {
            let tree = storage.tree(for: ["a"], depth: 1)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.value == .string("some"))
            #expect(e.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.count == 0)
        }

        do {
            let tree = storage.tree(for: ["a"], depth: 0)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)
            #expect(tree.children.count == 0)
        }
    }

    @Test("Partioning")
    func testPartitioning() {
        let now = Date()
        let later = now.addingTimeInterval(1)
        let all = [now, later]
        let index = all.partitioningIndex { $0 >= later }
        #expect(index == 1)
        #expect(all[1] == later)
    }

    @Test("History")
    func testGetHistory() throws {
        let storage = InMemoryStorage()

        do {
            let empty = storage.samples(for: [], from: nil, to: nil, limit: nil)
            #expect(empty.isEmpty)
        }
        do {
            let empty = storage.samples(for: [], from: nil, to: nil, limit: 1)
            #expect(empty.isEmpty)
        }
        do {
            let empty = storage.samples(for: [], from: Date(), to: nil, limit: nil)
            #expect(empty.isEmpty)
        }
        do {
            let empty = storage.samples(for: [], from:nil, to: Date(), limit: nil)
            #expect(empty.isEmpty)
        }

        let first = Date()
        storage.save(.integer(123), for: [], at: first)
        do {
            let one = storage.samples(for: [], from: nil, to: nil, limit: nil)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(123))
            #expect(one[0].timestamp == first)
        }
        do {
            // start date is exclusive, so no values expected
            let empty = storage.samples(for: [], from: first, to: nil, limit: nil)
            #expect(empty.isEmpty)
        }
        do {
            // end date is inclusive, so expect the value
            let one = storage.samples(for: [], from: nil, to: first, limit: nil)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(123))
            #expect(one[0].timestamp == first)
        }

        let second = first.addingTimeInterval(1.0)
        storage.save(.integer(234), for: [], at: second)
        do {
            let two = storage.samples(for: [], from: nil, to: nil, limit: nil)
            try #require(two.count == 2)
            // Values are returned newest first
            #expect(two[0].value == .integer(234))
            #expect(two[0].timestamp == second)
            #expect(two[1].value == .integer(123))
            #expect(two[1].timestamp == first)
        }
        do {
            // start date is exclusive, so expect only first value
            let one = storage.samples(for: [], from: second, to: nil, limit: nil)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(123))
            #expect(one[0].timestamp == first)
        }
        do {
            // end date is inclusive, so expect both values
            let two = storage.samples(for: [], from: nil, to: first, limit: nil)
            try #require(two.count == 2)
            // Values are returned newest first
            #expect(two[0].value == .integer(234))
            #expect(two[0].timestamp == second)
            #expect(two[1].value == .integer(123))
            #expect(two[1].timestamp == first)
        }
        do {
            // limit to 1, so only expect second value
            let one = storage.samples(for: [], from: nil, to: nil, limit: 1)
            try #require(one.count == 1)
            #expect(one[0].value == .integer(234))
            #expect(one[0].timestamp == second)
        }
    }

    @Test("History order")
    func testHistoryOrder() throws {
        let storage = InMemoryStorage()

        let now = Date()
        let samples = (0..<10).map {
            Sample(value: .integer(123 + $0), timestamp: now.addingTimeInterval(Double($0)))
        }
        for sample in samples {
            storage.save(sample.value, for: [], at: sample.timestamp)
        }

        let history = storage.samples(for: [])
        try #require(history.count == samples.count)
        #expect(history.first!.timestamp > history.last!.timestamp, "History should be sorted newest first")
        let reversedSamples = Array(samples.reversed())
        for index in history.indices {
            #expect(history[index].value == reversedSamples[index].value)
            #expect(history[index].timestamp.isVeryClose(to: reversedSamples[index].timestamp))
        }
    }
}
