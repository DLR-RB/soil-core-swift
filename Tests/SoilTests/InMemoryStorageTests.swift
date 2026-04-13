import Testing
import Soil

@Suite("InMemoryStorage")
struct InMemoryStorageTests {

    @Test("Store current value")
    func saveAndGetCurrentValue() async throws {
        let storage = InMemoryStorage()

        let value = Value.integer(123)
        let time = Timestamp.current()
        let path = ["a", "b", "c"]

        await storage.receive(value, for: path).wait()

        let stored = await storage.tree(for: path, depth: 0)
        let sample = try #require(stored.newestSample)
        #expect(sample.value == value)
        #expect(sample.isVeryClose(to: time))
        #expect(stored.children.isEmpty)
    }

    @Test("Store value with timestamp")
    func saveAndGetValueWithTimestamp() async throws {
        let storage = InMemoryStorage()

        let value = Value.integer(123)
        let time = Timestamp.current()
        let path = ["a", "b", "c"]

        await storage.receive(value, for: path, at: time).wait()

        let stored = await storage.tree(for: path, depth: 0)
        let sample = try #require(stored.newestSample)
        #expect(sample.value == value)
        #expect(sample.isVeryClose(to: time))
        #expect(stored.children.isEmpty)
    }

    @Test("Replace current value")
    func replaceCurrentValue() async throws {
        let storage = InMemoryStorage()

        let newValue = Value.integer(123)
        let newTime = Timestamp.current().addingTimeInterval(-1)
        let path = ["a", "b", "c"]

        let oldValue = Value.integer(234)
        let oldTime = newTime.addingTimeInterval(-10)

        await storage.receive(oldValue, for: path, at: oldTime).wait()

        do {
            // Get current value
            let stored = await storage.tree(for: path, depth: 0)
            let sample = try #require(stored.newestSample)
            #expect(sample.value == oldValue)
            #expect(sample.isVeryClose(to: oldTime))
            #expect(stored.children.isEmpty)
        }

        await storage.receive(newValue, for: path, at: newTime).wait()

        do {
            // Get current value
            let stored = await storage.currentTree(for: path, depth: 0)
            #expect(stored.samples.count == 1)
            let sample = try #require(stored.newestSample)
            #expect(sample.value == newValue)
            #expect(sample.isVeryClose(to: newTime))
            #expect(stored.children.isEmpty)
        }

        do {
            // Get old value
            let stored = await storage.tree(for: path, beforeOrAt: oldTime.addingTimeInterval(1), depth: 0)
            let sample = try #require(stored.newestSample)
            #expect(sample.value == oldValue)
            #expect(sample.isVeryClose(to: oldTime))
            #expect(stored.children.isEmpty)
        }

    }

    @Test("Store root value")
    func saveAndGetRootValue() async throws {
        let storage = InMemoryStorage()

        let value = Value.integer(123)
        let time = Timestamp.current()
        let path: Path = []

        await storage.receive(value, for: path, at: time).wait()

        let stored = await storage.tree(for: path, depth: 0)
        let sample = try #require(stored.newestSample)
        #expect(sample.value == value)
        #expect(sample.timestamp == time)
        #expect(stored.children.isEmpty)
    }

    @Test("Store tree")
    func storeTree() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        do {
            let cTree = ImmutableSampleTree(value: .string("hello"), timestamp: now)
            let fTree = ImmutableSampleTree(value: .double(3.14), timestamp: now)
            let bTree = ImmutableSampleTree(children: ["c" : cTree, "f" : fTree])
            let eTree = ImmutableSampleTree(value: .path(["z", "x"]), timestamp: now)
            let dTree = ImmutableSampleTree(children: ["e" : eTree])
            let aTree = ImmutableSampleTree(value: .integer(123), timestamp: now, children: [
                "d" : dTree
            ])
            let tree = ImmutableSampleTree(children: ["a" : aTree, "b" : bTree])
            await storage.receive(tree, for: []).wait()
        }

        do {
            let tree = await storage.tree(for: [])
            #expect(tree.children.count == 2)
            #expect(tree.samples.isEmpty)

            let a = try #require(tree.children["a"])
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(123))
            #expect(aSample.isVeryClose(to: now))
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.samples.isEmpty)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .path(["z", "x"]))
            #expect(eSample.isVeryClose(to: now))
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .string("hello"))
            #expect(cSample.isVeryClose(to: now))
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            let fSample = try #require(f.newestSample)
            #expect(fSample.value == .double(3.14))
            #expect(fSample.isVeryClose(to: now))
            #expect(f.children.isEmpty)
        }
    }

    @Test("Full tree")
    func getFullTree() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        await storage.receive(.integer(123), for: ["a"], at: now).wait()
        await storage.receive(.string("hello"), for: ["b", "c"], at: now).wait()
        await storage.receive(.path(["z", "x"]), for: ["a", "d", "e"], at: now).wait()
        await storage.receive(.double(3.14), for: ["b", "f"], at: now).wait()

        do {
            let tree = await storage.tree(for: [])
            #expect(tree.children.count == 2)
            #expect(tree.samples.isEmpty)

            let a = try #require(tree.children["a"])
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(123))
            #expect(aSample.isVeryClose(to: now))
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.samples.isEmpty)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .path(["z", "x"]))
            #expect(eSample.isVeryClose(to: now))
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .string("hello"))
            #expect(cSample.isVeryClose(to: now))
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            let fSample = try #require(f.newestSample)
            #expect(fSample.value == .double(3.14))
            #expect(fSample.isVeryClose(to: now))
            #expect(f.children.isEmpty)
        }
    }

    @Test("Limited tree")
    func getTreeWithDepth() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        await storage.receive(.integer(123), for: ["a"], at: now).wait()
        await storage.receive(.string("hello"), for: ["b", "c"], at: now).wait()
        await storage.receive(.path(["z", "x"]), for: ["a", "d", "e"], at: now).wait()
        await storage.receive(.double(3.14), for: ["b", "f"], at: now).wait()

        do {
            let tree = await storage.tree(for: [], depth: 0)
            #expect(tree.children.isEmpty)
            #expect(tree.samples.isEmpty)
        }

        do {
            let tree = await storage.tree(for: [], depth: 1)
            #expect(tree.children.count == 2)
            #expect(tree.samples.isEmpty)

            let a = try #require(tree.children["a"])
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(123))
            #expect(aSample.isVeryClose(to: now))
            #expect(a.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.isEmpty)
        }

        do {
            let b = await storage.tree(for: ["b"], depth: 0)
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 0)
        }

        do {
            let b = await storage.tree(for: ["b"], depth: 1)
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .string("hello"))
            #expect(cSample.isVeryClose(to: now))
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            let fSample = try #require(f.newestSample)
            #expect(fSample.value == .double(3.14))
            #expect(fSample.isVeryClose(to: now))
            #expect(f.children.isEmpty)
        }
    }

    @Test("Tree at time")
    func getFullTreeAtTime() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        let old = now.addingTimeInterval(-100)
        let queryTime = now.addingTimeInterval(-50)

        // Store old and new values in mixed order
        do {
            await storage.receive(.string("there"), for: ["b", "c"], at: old).wait()
            await storage.receive(.integer(123), for: ["a"], at: now).wait()
            await storage.receive(.string("hello"), for: ["b", "c"], at: now).wait()
            await storage.receive(.integer(234), for: ["a"], at: old).wait()
            await storage.receive(.double(42.1), for: ["b", "f"], at: old).wait()
            await storage.receive(.path(["z", "x"]), for: ["a", "d", "e"], at: now).wait()
            await storage.receive(.path(["y", "w"]), for: ["a", "d", "e"], at: old).wait()
            await storage.receive(.double(3.14), for: ["b", "f"], at: now).wait()
        }

        // Get current tree
        do {
            let tree = await storage.tree(for: [])
            #expect(tree.children.count == 2)
            #expect(tree.samples.isEmpty)

            let a = try #require(tree.children["a"])
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(123))
            #expect(aSample.isVeryClose(to: now))
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.samples.isEmpty)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .path(["z", "x"]))
            #expect(eSample.isVeryClose(to: now))
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .string("hello"))
            #expect(cSample.isVeryClose(to: now))
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            let fSample = try #require(f.newestSample)
            #expect(fSample.value == .double(3.14))
            #expect(fSample.isVeryClose(to: now))
            #expect(f.children.isEmpty)
        }
        // Get old tree
        do {
            let tree = await storage.tree(for: [], beforeOrAt: queryTime)
            #expect(tree.newestSample == nil)
            #expect(tree.children.count == 2)

            let a = try #require(tree.children["a"])
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(234))
            #expect(aSample.isVeryClose(to: old))
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.newestSample == nil)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .path(["y", "w"]))
            #expect(eSample.isVeryClose(to: old))
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.newestSample == nil)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .string("there"))
            #expect(cSample.isVeryClose(to: old))
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            let fSample = try #require(f.newestSample)
            #expect(fSample.value == .double(42.1))
            #expect(fSample.isVeryClose(to: old))
            #expect(f.children.isEmpty)
        }
    }

    @Test("Limited tree at time")
    func getTreeWithDepthAtTime() async throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        let old = now.addingTimeInterval(-100)
        let queryTime = now.addingTimeInterval(-50)

        // Store old and new values in mixed order
        do {
            await storage.receive(.string("there"), for: ["b", "c"], at: old).wait()
            await storage.receive(.integer(123), for: ["a"], at: now).wait()
            await storage.receive(.string("hello"), for: ["b", "c"], at: now).wait()
            await storage.receive(.integer(234), for: ["a"], at: old).wait()
            await storage.receive(.double(42.1), for: ["b", "f"], at: old).wait()
            await storage.receive(.path(["z", "x"]), for: ["a", "d", "e"], at: now).wait()
            await storage.receive(.path(["y", "w"]), for: ["a", "d", "e"], at: old).wait()
            await storage.receive(.double(3.14), for: ["b", "f"], at: now).wait()
        }

        do {
            let root = await storage.tree(for: [], beforeOrAt: queryTime, depth: 1)
            #expect(root.children.count == 2)
            #expect(root.samples.isEmpty)

            let a = try #require(root.children["a"])
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(234))
            #expect(aSample.isVeryClose(to: old))
            #expect(a.children.count == 0)

            let b = try #require(root.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 0)
        }

        do {
            let a = await storage.tree(for: ["a"], beforeOrAt: queryTime, depth: 1)
            let aSample = try #require(a.newestSample)
            #expect(aSample.value == .integer(234))
            #expect(aSample.isVeryClose(to: old))
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.samples.isEmpty)
            #expect(d.children.count == 0)
        }

        do {
            let d = await storage.tree(for: ["a", "d"], beforeOrAt: queryTime, depth: 1)
            #expect(d.samples.isEmpty)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .path(["y", "w"]))
            #expect(eSample.isVeryClose(to: old))
            #expect(e.children.isEmpty)
        }

        do {
            let e = await storage.tree(for: ["a", "d", "e"], beforeOrAt: queryTime, depth: 1)
            let eSample = try #require(e.newestSample)
            #expect(eSample.value == .path(["y", "w"]))
            #expect(eSample.isVeryClose(to: old))
            #expect(e.children.isEmpty)
        }

        do {
            let b = await storage.tree(for: ["b"], beforeOrAt: queryTime, depth: 1)
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            let cSample = try #require(c.newestSample)
            #expect(cSample.value == .string("there"))
            #expect(cSample.isVeryClose(to: old))
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            let fSample = try #require(f.newestSample)
            #expect(fSample.value == .double(42.1))
            #expect(fSample.isVeryClose(to: old))
            #expect(f.children.isEmpty)
        }
    }

    @Test("Full history")
    func getFullHistory() async {
        let storage = InMemoryStorage()

        let old = Timestamp.current().addingTimeInterval(-10)
        let values = (0..<10).map {
            Sample(value: .integer($0), timestamp: old.addingTimeInterval(Double($0)))
        }
        do {
            for sample in values {
                await storage.receive(sample.value, for: ["a"], at: sample.timestamp).wait()
            }
        }

        do {
            let samples = await storage.samples(for: ["a"])
            #expect(samples.count == values.count)
            #expect(samples == values)
        }

        // Test shuffled insert
        do {
            for sample in values.shuffled() {
                await storage.receive(sample.value, for: ["b"], at: sample.timestamp).wait()
            }
        }

        do {
            let samples = await storage.samples(for: ["b"])
            #expect(samples.count == values.count)
            #expect(samples == values)
        }
    }

    private func databaseWithShuffledValues(count: Int = 100, path: Path = ["a"]) async -> (storage: Storage, start: Timestamp, path: Path) {
        let storage = InMemoryStorage()

        let start = Timestamp.current().addingTimeInterval(Double(-count))
        let values = (0..<count).map {
            Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0)))
        }

        for sample in values.shuffled() {
            await storage.receive(sample.value, for: path, at: sample.timestamp).wait()
        }
        return (storage, start, path)
    }

    @Test("Limited history")
    func getFullHistoryWithLimit() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let samples = await storage.samples(for: path, from: nil, to: nil, limit: 10)
        #expect(samples.count == 10)
        let expected = (0..<10).map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }

    @Test("History with start")
    func getHistoryWithStart() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let samples = await storage.samples(for: path, from: begin, to: nil, limit: nil)
        #expect(samples.count == 50)
        let expected = (0..<50).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Limited history with start")
    func getHistoryWithStartAndLimit() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let samples = await storage.samples(for: path, from: begin, to: nil, limit: 20)
        #expect(samples.count == 20)
        let expected = (0..<20).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Empty history with start")
    func getEmptyHistoryWithStart() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(100)
        let samples = await storage.samples(for: path, from: begin, to: nil, limit: nil)
        #expect(samples.count == 0)
    }

    /**
     When requesting history with only the end date set, then we expect descending order of the results.
     */
    @Test("History with end")
    func getHistoryWithEnd() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let end = start.addingTimeInterval(49.5)
        let samples = await storage.samples(for: path, from: nil, to: end, limit: nil)
        #expect(samples.count == 50)
        let expected = (0..<50).reversed().map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }

    /**
     When requesting history with only the end date set and a limit,
     then we expect descending order of the results,
     limited from the latest timestamps
     */
    @Test("Limited history with end")
    func getHistoryWithEndAndLimit() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let end = start.addingTimeInterval(49.5)
        let samples = await storage.samples(for: path, from: nil, to: end, limit: 20)
        #expect(samples.count == 20)
        let expected = (30..<50).reversed().map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }

    @Test("Empty history with end")
    func getEmptyHistoryWithEnd() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let end = start.addingTimeInterval(-10)
        let samples = await storage.samples(for: path, from: nil, to: end, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("History in interval")
    func getHistoryInInterval() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let end = begin.addingTimeInterval(20)
        let samples = await storage.samples(for: path, from: begin, to: end, limit: nil)
        #expect(samples.count == 20)
        let expected = (0..<20).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Limited history in interval")
    func getHistoryInIntervalWithLimit() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let end = begin.addingTimeInterval(20)
        let samples = await storage.samples(for: path, from: begin, to: end, limit: 10)
        #expect(samples.count == 10)
        let expected = (0..<10).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Empty history in interval")
    func getEmptyHistoryInInterval() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(-20)
        let end = begin.addingTimeInterval(-10)
        let samples = await storage.samples(for: path, from: begin, to: end, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("Empty history in reversed interval")
    func getEmptyHistoryInReversedInterval() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(-10)
        let end = begin.addingTimeInterval(-20)
        let samples = await storage.samples(for: path, from: begin, to: end, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("Reversed history in interval")
    func getReversedHistoryInInterval() async {
        let (storage, start, path) = await databaseWithShuffledValues()

        let begin = start.addingTimeInterval(69.5)
        let end = begin.addingTimeInterval(-20)
        let samples = await storage.samples(for: path, from: begin, to: end, limit: 10)
        #expect(samples.count == 10)
        let expected = (60..<70).reversed().map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }
}