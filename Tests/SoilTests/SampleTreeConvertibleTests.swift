import Foundation
import Testing
import Soil

private struct Position: Codable, Equatable, SampleTreeConvertible {
    var x: Double
    var y: Double
}

private struct Robot: Codable, Equatable, ValueConvertible, SampleTreeConvertible {
    var name: String
    var position: Position
    var waypoints: [Position] = []
    var note: String? = nil
}

private enum Mode: String, ValueConvertible, SampleTreeConvertible {
    case idle, active
}

private struct Counter: Codable, SampleTreeConvertible {
    var count: UInt64
}

@Suite("Sample tree convertible")
struct SampleTreeConvertibleTests {

    @Test("Values are stored at the root")
    func values() throws {
        let tree = try Mode.active.sampleTree
        #expect(tree.isEqual(to: ImmutableSampleTree(value: "active")))
        #expect(Mode(sampleTree: tree) == .active)
        #expect(Mode(sampleTree: ImmutableSampleTree(value: "other")) == nil)
        #expect(Mode(sampleTree: ImmutableSampleTree()) == nil)
    }

    @Test("Codable types are expanded into child nodes")
    func codable() throws {
        let robot = Robot(name: "R2", position: .init(x: 1, y: 2), waypoints: [.init(x: 3, y: 4)])
        let tree = try robot.sampleTree

        #expect(tree.samples.isEmpty)
        #expect(tree.children["name"]?.currentValue == "R2")
        #expect(tree.children["position"]?.samples.isEmpty == true)
        #expect(tree.children["position"]?.children["x"]?.currentValue == 1.0)
        #expect(tree.children["position"]?.children["y"]?.currentValue == 2.0)
        #expect(tree.children["waypoints"]?.currentValue == [["x": 3.0, "y": 4.0]])
        #expect(tree.children["note"] == nil)

        #expect(Robot(sampleTree: tree) == robot)
        #expect(Position(sampleTree: tree) == nil)
    }

    @Test("Unrepresentable values throw")
    func unrepresentable() {
        #expect(throws: EncodingError.self) { try Counter(count: .max).sampleTree }
    }

    @Test("Receiver and provider")
    func receiverAndProvider() async throws {
        let storage = InMemoryStorage()
        let robot = Robot(name: "R2", position: .init(x: 1, y: 2), note: "Beep")

        try await storage.accept(tree: robot, for: ["robot"], at: .current()).wait()
        try await storage.accept(tree: Mode.idle, for: ["mode"]).wait()

        #expect(await storage.currentTree(for: ["robot"], as: Robot.self) == robot)
        #expect(await storage.currentTree(for: ["robot", "position"], as: Position.self) == robot.position)
        #expect(await storage.currentValue(for: ["robot", "position", "x"]) == 1.0)
        #expect(await storage.currentTree(for: ["mode"], as: Mode.self) == .idle)

        // Updating a single node is reflected in the converted value
        await storage.accept(5.0, for: ["robot", "position", "y"]).wait()
        #expect(await storage.currentTree(for: ["robot"], as: Robot.self)?.position.y == 5.0)
    }

    @Test("Messages")
    func messages() throws {
        let position = Position(x: 1, y: 2)
        let timestamp = Timestamp(timeIntervalSince1970: 100)
        let message = try Message.tree(position, for: ["position"], at: timestamp)

        #expect(message.type == .data)
        #expect(message.path == ["position"])
        #expect(message.data.children["x"]?.samples == [.init(value: 1.0, timestamp: timestamp)])
        #expect(Position(sampleTree: message.data) == position)
        #expect(throws: EncodingError.self) { try Message.tree(Counter(count: .max), for: []) }
    }

    @Test("Tree storage nodes")
    func treeNodes() async throws {
        let storage = InMemoryStorage()
        let robot = storage.treeNode(at: ["robot"], as: Robot.self)
        let value = Robot(name: "R2", position: .init(x: 1, y: 2))

        #expect(robot.path == ["robot"])
        #expect(await robot.value() == nil)

        try await robot.set(value).wait()
        #expect(await robot.value() == value)

        let position = robot.node.treeChild(named: "position", as: Position.self)
        try await position.set(.init(x: 3, y: 4)).wait()
        #expect(await robot.value()?.position == .init(x: 3, y: 4))
        #expect(await storage.node(at: ["robot", "position"]).treeNode(as: Position.self).value() == .init(x: 3, y: 4))
    }
}
