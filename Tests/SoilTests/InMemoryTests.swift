import Testing
import Soil

@Suite("InMemoryDatabase")
struct InMemoryDatabase {

    @Test("Store current value")
    func saveAndGetCurrentValue() throws {
        let storage = InMemoryStorage()

        let value = Value.integer(123)
        let time = Timestamp.current()
        let path = ["a", "b", "c"]

        storage.save(value, for: path)

        let stored = storage.tree(for: path, depth: 0)
        let storedValue = try #require(stored.value)
        #expect(storedValue == value)
        let storedTime = try #require(stored.timestamp)
        #expect(storedTime.isVeryClose(to: time))
        #expect(stored.children.isEmpty)
    }

    @Test("Store value with timestamp")
    func saveAndGetValueWithTimestamp() throws {
        let storage = InMemoryStorage()

        let value = Value.integer(123)
        let time = Timestamp.current()
        let path = ["a", "b", "c"]

        storage.save(value, for: path, at: time)

        let stored = storage.tree(for: path, depth: 0)
        let storedValue = try #require(stored.value)
        #expect(storedValue == value)
        let storedTime = try #require(stored.timestamp)
        #expect(storedTime.isVeryClose(to: time))
        #expect(stored.children.isEmpty)
    }

    @Test("Replace current value")
    func replaceCurrentValue() throws {
        let storage = InMemoryStorage()

        let newValue = Value.integer(123)
        let newTime = Timestamp.current()
        let path = ["a", "b", "c"]

        let oldValue = Value.integer(234)
        let oldTime = newTime.addingTimeInterval(-10)

        storage.save(oldValue, for: path, at: oldTime)

        do {
            // Get current value
            let stored = storage.tree(for: path, depth: 0)
            let storedValue = try #require(stored.value)
            #expect(storedValue == oldValue)
            let storedTime = try #require(stored.timestamp)
            #expect(storedTime.isVeryClose(to: oldTime))
            #expect(stored.children.isEmpty)
        }

        storage.save(newValue, for: path, at: newTime)

        do {
            // Get current value
            let stored = storage.tree(for: path, depth: 0)
            let storedValue = try #require(stored.value)
            #expect(storedValue == newValue)
            let storedTime = try #require(stored.timestamp)
            #expect(storedTime.isVeryClose(to: newTime))
            #expect(stored.children.isEmpty)
        }

        do {
            // Get old value
            let stored = storage.tree(for: path, beforeOrAt: oldTime.addingTimeInterval(1), depth: 0)
            let storedValue = try #require(stored.value)
            #expect(storedValue == oldValue)
            let storedTime = try #require(stored.timestamp)
            #expect(storedTime.isVeryClose(to: oldTime))
            #expect(stored.children.isEmpty)
        }

    }

    @Test("Store root value")
    func saveAndGetRootValue() throws {
        let storage = InMemoryStorage()

        let value = Value.integer(123)
        let time = Timestamp.current()
        let path: Path = []

        storage.save(value, for: path, at: time)

        let stored = storage.tree(for: path, depth: 0)
        let storedValue = try #require(stored.value)
        #expect(storedValue == value)
        let storedTime = try #require(stored.timestamp)
        #expect(storedTime == time)
        #expect(stored.children.isEmpty)
    }

    @Test("Full tree")
    func getFullTree() throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        storage.save(.integer(123), for: ["a"], at: now)
        storage.save(.string("hello"), for: ["b", "c"], at: now)
        storage.save(.path(["z", "x"]), for: ["a", "d", "e"], at: now)
        storage.save(.double(3.14), for: ["b", "f"], at: now)

        do {
            let tree = storage.tree(for: [])
            #expect(tree.children.count == 2)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)

            let a = try #require(tree.children["a"])
            #expect(a.value == .integer(123))
            #expect(a.timestamp?.isVeryClose(to: now) ?? false)
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.value == nil)
            #expect(d.timestamp == nil)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            #expect(e.value == .path(["z", "x"]))
            #expect(e.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            #expect(c.value == .string("hello"))
            #expect(c.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            #expect(f.value == .double(3.14))
            #expect(f.timestamp?.isVeryClose(to: now) ?? false)
            #expect(f.children.isEmpty)
        }
    }

    @Test("Limited tree")
    func getTreeWithDepth() throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        storage.save(.integer(123), for: ["a"], at: now)
        storage.save(.string("hello"), for: ["b", "c"], at: now)
        storage.save(.path(["z", "x"]), for: ["a", "d", "e"], at: now)
        storage.save(.double(3.14), for: ["b", "f"], at: now)

        do {
            let tree = storage.tree(for: [], depth: 0)
            #expect(tree.children.isEmpty)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)
        }

        do {
            let tree = storage.tree(for: [], depth: 1)
            #expect(tree.children.count == 2)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)

            let a = try #require(tree.children["a"])
            #expect(a.value == .integer(123))
            #expect(a.timestamp?.isVeryClose(to: now) ?? false)
            #expect(a.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.isEmpty)
        }

        do {
            let b = storage.tree(for: ["b"], depth: 0)
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 0)
        }

        do {
            let b = storage.tree(for: ["b"], depth: 1)
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            #expect(c.value == .string("hello"))
            #expect(c.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            #expect(f.value == .double(3.14))
            #expect(f.timestamp?.isVeryClose(to: now) ?? false)
            #expect(f.children.isEmpty)
        }
    }

    @Test("Tree at time")
    func getFullTreeAtTime() throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        let old = now.addingTimeInterval(-100)
        let queryTime = now.addingTimeInterval(-50)

        // Store old and new values in mixed order
        do {
            storage.save(.string("there"), for: ["b", "c"], at: old)
            storage.save(.integer(123), for: ["a"], at: now)
            storage.save(.string("hello"), for: ["b", "c"], at: now)
            storage.save(.integer(234), for: ["a"], at: old)
            storage.save(.double(42.1), for: ["b", "f"], at: old)
            storage.save(.path(["z", "x"]), for: ["a", "d", "e"], at: now)
            storage.save(.path(["y", "w"]), for: ["a", "d", "e"], at: old)
            storage.save(.double(3.14), for: ["b", "f"], at: now)
        }

        // Get current tree
        do {
            let tree = storage.tree(for: [])
            #expect(tree.children.count == 2)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)

            let a = try #require(tree.children["a"])
            #expect(a.value == .integer(123))
            #expect(a.timestamp?.isVeryClose(to: now) ?? false)
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.value == nil)
            #expect(d.timestamp == nil)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            #expect(e.value == .path(["z", "x"]))
            #expect(e.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            #expect(c.value == .string("hello"))
            #expect(c.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            #expect(f.value == .double(3.14))
            #expect(f.timestamp?.isVeryClose(to: now) ?? false)
            #expect(f.children.isEmpty)
        }
        // Get old tree
        do {
            let tree = storage.tree(for: [], beforeOrAt: queryTime)
            #expect(tree.children.count == 2)
            #expect(tree.value == nil)
            #expect(tree.timestamp == nil)

            let a = try #require(tree.children["a"])
            #expect(a.value == .integer(234))
            #expect(a.timestamp?.isVeryClose(to: old) ?? false)
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.value == nil)
            #expect(d.timestamp == nil)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            #expect(e.value == .path(["y", "w"]))
            #expect(e.timestamp?.isVeryClose(to: old) ?? false)
            #expect(e.children.isEmpty)

            let b = try #require(tree.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            #expect(c.value == .string("there"))
            #expect(c.timestamp?.isVeryClose(to: old) ?? false)
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            #expect(f.value == .double(42.1))
            #expect(f.timestamp?.isVeryClose(to: old) ?? false)
            #expect(f.children.isEmpty)
        }
    }

    @Test("Limited tree at time")
    func getTreeWithDepthAtTime() throws {
        let storage = InMemoryStorage()

        let now = Timestamp.current()
        let old = now.addingTimeInterval(-100)
        let queryTime = now.addingTimeInterval(-50)

        // Store old and new values in mixed order
        do {
            storage.save(.string("there"), for: ["b", "c"], at: old)
            storage.save(.integer(123), for: ["a"], at: now)
            storage.save(.string("hello"), for: ["b", "c"], at: now)
            storage.save(.integer(234), for: ["a"], at: old)
            storage.save(.double(42.1), for: ["b", "f"], at: old)
            storage.save(.path(["z", "x"]), for: ["a", "d", "e"], at: now)
            storage.save(.path(["y", "w"]), for: ["a", "d", "e"], at: old)
            storage.save(.double(3.14), for: ["b", "f"], at: now)
        }

        do {
            let root = storage.tree(for: [], beforeOrAt: queryTime, depth: 1)
            #expect(root.children.count == 2)
            #expect(root.value == nil)
            #expect(root.timestamp == nil)

            let a = try #require(root.children["a"])
            #expect(a.value == .integer(234))
            #expect(a.timestamp?.isVeryClose(to: old) ?? false)
            #expect(a.children.count == 0)

            let b = try #require(root.children["b"])
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 0)
        }

        do {
            let a = storage.tree(for: ["a"], beforeOrAt: queryTime, depth: 1)
            #expect(a.value == .integer(234))
            #expect(a.timestamp?.isVeryClose(to: old) ?? false)
            #expect(a.children.count == 1)

            let d = try #require(a.children["d"])
            #expect(d.value == nil)
            #expect(d.timestamp == nil)
            #expect(d.children.count == 0)
        }

        do {
            let d: Tree = storage.tree(for: ["a", "d"], beforeOrAt: queryTime, depth: 1)
            #expect(d.value == nil)
            #expect(d.timestamp == nil)
            #expect(d.children.count == 1)

            let e = try #require(d.children["e"])
            #expect(e.value == .path(["y", "w"]))
            #expect(e.timestamp?.isVeryClose(to: old) ?? false)
            #expect(e.children.isEmpty)
        }

        do {
            let e = storage.tree(for: ["a", "d", "e"], beforeOrAt: queryTime, depth: 1)
            #expect(e.value == .path(["y", "w"]))
            #expect(e.timestamp?.isVeryClose(to: old) ?? false)
            #expect(e.children.isEmpty)
        }

        do {
            let b = storage.tree(for: ["b"], beforeOrAt: queryTime, depth: 1)
            #expect(b.value == nil)
            #expect(b.timestamp == nil)
            #expect(b.children.count == 2)

            let c = try #require(b.children["c"])
            #expect(c.value == .string("there"))
            #expect(c.timestamp?.isVeryClose(to: old) ?? false)
            #expect(c.children.isEmpty)

            let f = try #require(b.children["f"])
            #expect(f.value == .double(42.1))
            #expect(f.timestamp?.isVeryClose(to: old) ?? false)
            #expect(f.children.isEmpty)
        }
    }

    @Test("Full history")
    func getFullHistory() throws {
        let storage = InMemoryStorage()

        let old = Timestamp.current().addingTimeInterval(-10)
        let values = (0..<10).map {
            Sample(value: .integer($0), timestamp: old.addingTimeInterval(Double($0)))
        }
        do {
            for sample in values {
                storage.save(sample.value, for: ["a"], at: sample.timestamp)
            }
        }

        do {
            let samples = storage.samples(for: ["a"])
            #expect(samples.count == values.count)
            #expect(samples == values)
        }

        // Test shuffled insert
        do {
            for sample in values.shuffled() {
                storage.save(sample.value, for: ["b"], at: sample.timestamp)
            }
        }

        do {
            let samples = storage.samples(for: ["b"])
            #expect(samples.count == values.count)
            #expect(samples == values)
        }
    }

    private func databaseWithShuffledValues(count: Int = 100, path: Path = ["a"]) -> (storage: Storage, start: Timestamp, path: Path) {
        let storage = InMemoryStorage()

        let start = Timestamp.current().addingTimeInterval(Double(-count))
        let values = (0..<count).map {
            Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0)))
        }

        for sample in values.shuffled() {
            storage.save(sample.value, for: path, at: sample.timestamp)
        }
        return (storage, start, path)
    }

    @Test("Limited history")
    func getFullHistoryWithLimit() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let samples = storage.samples(for: path, from: nil, to: nil, limit: 10)
        #expect(samples.count == 10)
        let expected = (0..<10).map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }

    @Test("History with start")
    func getHistoryWithStart() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let samples = storage.samples(for: path, from: begin, to: nil, limit: nil)
        #expect(samples.count == 50)
        let expected = (0..<50).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Limited history with start")
    func getHistoryWithStartAndLimit() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let samples = storage.samples(for: path, from: begin, to: nil, limit: 20)
        #expect(samples.count == 20)
        let expected = (0..<20).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Empty history with start")
    func getEmptyHistoryWithStart() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(100)
        let samples = storage.samples(for: path, from: begin, to: nil, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("History with end")
    func getHistoryWithEnd() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let end = start.addingTimeInterval(49.5)
        let samples = storage.samples(for: path, from: nil, to: end, limit: nil)
        #expect(samples.count == 50)
        let expected = (0..<50).map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }

    @Test("Limited history with end")
    func getHistoryWithEndAndLimit() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let end = start.addingTimeInterval(49.5)
        let samples = storage.samples(for: path, from: nil, to: end, limit: 20)
        #expect(samples.count == 20)
        let expected = (0..<20).map { Sample(value: .integer($0), timestamp: start.addingTimeInterval(Double($0))) }
        #expect(samples == expected)
    }

    @Test("Empty history with end")
    func getEmptyHistoryWithEnd() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let end = start.addingTimeInterval(-10)
        let samples = storage.samples(for: path, from: nil, to: end, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("History in interval")
    func getHistoryInInterval() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let end = begin.addingTimeInterval(20)
        let samples = storage.samples(for: path, from: begin, to: end, limit: nil)
        #expect(samples.count == 20)
        let expected = (0..<20).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Limited history in interval")
    func getHistoryInIntervalWithLimit() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(49.5)
        let end = begin.addingTimeInterval(20)
        let samples = storage.samples(for: path, from: begin, to: end, limit: 10)
        #expect(samples.count == 10)
        let expected = (0..<10).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }
        #expect(samples == expected)
    }

    @Test("Empty history in interval")
    func getEmptyHistoryInInterval() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(-20)
        let end = begin.addingTimeInterval(-10)
        let samples = storage.samples(for: path, from: begin, to: end, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("Empty history in reversed interval")
    func getEmptyHistoryInReversedInterval() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(-10)
        let end = begin.addingTimeInterval(-20)
        let samples = storage.samples(for: path, from: begin, to: end, limit: nil)
        #expect(samples.count == 0)
    }

    @Test("Reversed history in interval")
    func getReversedHistoryInInterval() throws {
        let (storage, start, path) = databaseWithShuffledValues()

        let begin = start.addingTimeInterval(69.5)
        let end = begin.addingTimeInterval(-20)
        let samples = storage.samples(for: path, from: begin, to: end, limit: 10)
        #expect(samples.count == 10)
        let expected = (0..<10).map { Sample(value: .integer(50 + $0), timestamp: start.addingTimeInterval(Double(50 + $0))) }.reversed()
        #expect(samples == Array(expected))
    }
}