import Foundation
import Soil
import Testing

@Suite("In-memory synchronous storage")
struct InMemorySynchronousStorageTests {

    private let base = Date(timeIntervalSince1970: 1000)

    private func time(_ offset: Double) -> Timestamp {
        base.addingTimeInterval(offset)
    }

    /// Fill both storages with the same data
    private func makeStorages() async -> (InMemorySynchronousStorage, InMemoryStorage) {
        let model = InMemorySynchronousStorage()
        let reference = InMemoryStorage()
        let tree = ImmutableSampleTree(
            samples: (1...5).map { Sample(value: .integer($0), timestamp: time(Double($0))) },
            children: [
                "a": ImmutableSampleTree(
                    samples: [Sample(value: .string("x"), timestamp: time(2)), Sample(value: .string("y"), timestamp: time(4))],
                    children: ["b": ImmutableSampleTree(sample: Sample(value: .integer(9), timestamp: time(3)))]
                )
            ]
        )
        model.accept(tree, for: ["root"])
        await reference.accept(tree, for: ["root"]).wait()
        return (model, reference)
    }

    @Test("Same results as InMemoryStorage", arguments: [
        (nil, nil, nil, nil),
        (nil, nil, nil, 2),
        (nil, 3.0, 0, 1),
        (nil, 3.5, nil, 2),
        (1.0, nil, nil, 2),
        (1.0, 4.0, 1, nil),
        (4.0, 1.0, nil, 2),
        (2.0, 2.0, nil, nil),
    ] as [(Double?, Double?, Int?, Int?)])
    func sameResults(start: Double?, end: Double?, depth: Int?, limit: Int?) async {
        let (model, reference) = await makeStorages()
        let expected = await reference.tree(for: ["root"], from: start.map(time), to: end.map(time), depth: depth, limitPerNode: limit)
        let result = model.tree(for: ["root"], from: start.map(time), to: end.map(time), depth: depth, limitPerNode: limit)
        #expect(result.isEqual(to: expected), "\(result)\n!=\n\(expected)")
    }

    @Test("Delete intervals", arguments: [
        (nil, nil, 0),
        (nil, 3.0, 0),
        (2.0, nil, 0),
        (1.0, 4.0, 0),
        (4.0, 1.0, 0),
        (nil, nil, 1),
        (nil, 3.0, 1),
        (1.0, 4.0, nil),
    ] as [(Double?, Double?, Int?)])
    func delete(start: Double?, end: Double?, depth: Int?) async {
        let (model, reference) = await makeStorages()
        model.delete(path: ["root"], from: start.map(time), to: end.map(time), depth: depth)
        await reference.delete(path: ["root"], from: start.map(time), to: end.map(time), depth: depth).wait()
        // Compare the full tree, so that deletions below the path are also checked
        let expected = await reference.tree(for: [], from: nil, to: nil, depth: nil, limitPerNode: nil)
        let result = model.tree(for: [], from: nil, to: nil, depth: nil, limitPerNode: nil)
        #expect(result.isEqual(to: expected), "\(result)\n!=\n\(expected)")
    }

    @Test("Delete removes empty nodes")
    func deleteRemovesEmptyNodes() async {
        let (_, reference) = await makeStorages()
        await reference.delete(path: ["root"], from: nil, to: nil, depth: nil).wait()
        let tree = await reference.tree(for: ["root"], from: nil, to: nil, depth: nil, limitPerNode: nil)
        #expect(tree.children.isEmpty)
    }

    @Test("Delete with depth 0 keeps child samples")
    func deleteKeepsChildren() async {
        let (_, reference) = await makeStorages()
        await reference.delete(path: ["root"], from: nil, to: nil, depth: 0).wait()
        #expect(await reference.samples(for: ["root"]).isEmpty)
        #expect(await reference.samples(for: ["root", "a"]).count == 2)
        #expect(await reference.samples(for: ["root", "a", "b"]).count == 1)
    }

    @Test("Delete sub-tree")
    func deleteTree() async {
        let (model, _) = await makeStorages()
        model.delete(path: ["root"], from: nil, to: nil, depth: nil)
        #expect(model.tree(for: [], from: nil, to: nil, depth: nil, limitPerNode: nil).isEmpty)
    }

    @Test("Usable as SOIL storage")
    func asyncAccess() async {
        let storage: any Storage = InMemorySynchronousStorage()
        await storage.accept(.integer(1), for: ["a"]).wait()
        #expect(await storage.currentValue(for: ["a"]) == .integer(1))
    }

    @Test("Child values")
    func childValues() async {
        let (model, _) = await makeStorages()
        #expect(model.childValues(of: ["root"]) == ["a": .string("y")])
        #expect(model.childValues(of: ["root"], beforeOrAt: time(3)) == ["a": .string("x")])
        #expect(model.value(for: ["root"], beforeOrAt: time(2.5)) == .integer(2))
    }
}
