import Foundation
import Testing
import Soil

private enum Priority: Int, ValueConvertible {
    case low, high
}

private struct Address: Codable, Equatable, ValueConvertible {
    var street: String
    var city: String
    var tags: [String] = []
    var moved: Date? = nil
}

private struct Link: Codable, Equatable, ValueConvertible {
    var target: Path
}

private struct Counter: Codable, ValueConvertible {
    var count: UInt64
}

private struct Small: Codable, ValueConvertible {
    var byte: Int8
    var ratio: Float
}

@Suite("Values")
struct ValueTests {

    private func roundTrip<T: ValueConvertible & Equatable>(_ value: T, expected: Value) throws {
        #expect(try value.soilValue == expected)
        #expect(T(soilValue: expected) == value)
    }

    @Test("Primitives")
    func primitives() throws {
        try roundTrip(42, expected: .integer(42))
        try roundTrip(UInt8(7), expected: .integer(7))
        try roundTrip(true, expected: .integer(1))
        try roundTrip(2.5, expected: .double(2.5))
        try roundTrip(Float(1.5), expected: .double(1.5))
        try roundTrip("abc", expected: .string("abc"))
        try roundTrip(Data([1, 2]), expected: .data(Data([1, 2])))
        try roundTrip(Date(timeIntervalSince1970: 100), expected: .double(100))
        let uuid = UUID()
        try roundTrip(uuid, expected: .string(uuid.uuidString))
    }

    @Test("Integer conversion limits")
    func integerLimits() throws {
        #expect(UInt8(soilValue: .integer(300)) == nil)
        #expect(Int(soilValue: .double(3.0)) == 3)
        #expect(Int(soilValue: .double(3.5)) == nil)
        #expect(Double(soilValue: .integer(3)) == 3.0)
        #expect(Int(soilValue: .string("3")) == nil)
        try roundTrip(UInt64(5), expected: .integer(5))
    }

    @Test("Out of range conversions fail instead of clamping")
    func noClamping() {
        // Integers
        #expect(Int8(soilValue: .integer(1000)) == nil)
        #expect(Int8(soilValue: .integer(-1000)) == nil)
        #expect(UInt(soilValue: .integer(-1)) == nil)
        #expect(Int(soilValue: .double(1e30)) == nil)
        #expect(Int(soilValue: .double(.infinity)) == nil)
        #expect(Int(soilValue: .double(-.infinity)) == nil)
        #expect(Int(soilValue: .double(.nan)) == nil)
        #expect(Int(soilValue: .integer(.max)) == .max)
        // Floating point
        #expect(Float(soilValue: .double(1e300)) == nil)
        #expect(Float(soilValue: .double(-1e300)) == nil)
        #expect(Float(soilValue: .double(.infinity)) == .infinity)
        #expect(Float(soilValue: .double(.nan))?.isNaN == true)
        #expect(Float(soilValue: .double(Double(Float.greatestFiniteMagnitude))) == .greatestFiniteMagnitude)
        #expect(Float(soilValue: .integer(.max)) == Float(Int.max))
        #expect(Double(soilValue: .double(.infinity)) == .infinity)
        // Dates
        #expect(Date(soilValue: .double(.nan)) == nil)
        #expect(Date(soilValue: .double(.infinity)) == nil)
        #expect(Date(soilValue: .integer(.max)) != nil)
        // Codable types
        #expect(Small(soilValue: .map(["byte": .integer(1), "ratio": .double(0.5)])) != nil)
        #expect(Small(soilValue: .map(["byte": .integer(1000), "ratio": .double(0.5)])) == nil)
        #expect(Small(soilValue: .map(["byte": .integer(1), "ratio": .double(1e300)])) == nil)
    }

    @Test("Received values are clamped, but converted strictly")
    func receivedValues() throws {
        let json = #"{"type": "integer", "value": 99999999999999999999}"#
        let message = try JsonEncoding().decode(Data(json.utf8))
        let value = try #require(message.data.samples.first?.value)
        // Clamped while decoding the message
        #expect(value == .integer(.max))
        #expect(Int(soilValue: value) == .max)
        // Not clamped again when converting to smaller types
        #expect(Int32(soilValue: value) == nil)
    }

    @Test("Unrepresentable values throw")
    func unrepresentable() {
        #expect(throws: EncodingError.self) { try UInt64.max.soilValue }
        #expect(throws: EncodingError.self) { try [UInt.max].soilValue }
        #expect(throws: EncodingError.self) { try Counter(count: .max).soilValue }
    }

    @Test("Containers")
    func containers() throws {
        try roundTrip([1, 2], expected: .list([.integer(1), .integer(2)]))
        try roundTrip(["a": 1], expected: .map(["a": .integer(1)]))
        try roundTrip(Int?.none, expected: .null)
        try roundTrip(Int?.some(3), expected: .integer(3))
        // Paths and string arrays are distinct
        try roundTrip(["a", "b"] as Path, expected: .path(["a", "b"]))
        try roundTrip(["a", "b"] as [String], expected: .list([.string("a"), .string("b")]))
        #expect([String](soilValue: .path(["a", "b"])) == nil)
        #expect(Path(soilValue: .list([.string("a")])) == nil)
        #expect(try Set([3]).soilValue == .list([.integer(3)]))
        // Invalid values are not treated as `nil`
        #expect(Int?(soilValue: .string("a")) == nil)
    }

    @Test("Nested optionals")
    func nestedOptionals() throws {
        // The failable initializers add another level of optionals
        let value = try #require(Value?(soilValue: .null))
        #expect(value == .some(.null))
        let int = try #require(Int??(soilValue: .null))
        #expect(int == .some(.none))
        try roundTrip(Value?.some(.null), expected: .null)
        try roundTrip(Int??.some(.none), expected: .null)
        try roundTrip(Int??.some(3), expected: .integer(3))
    }

    @Test("Raw representable")
    func rawRepresentable() throws {
        try roundTrip(Priority.high, expected: .integer(1))
        #expect(Priority(soilValue: .integer(5)) == nil)
    }

    @Test("Codable")
    func codable() throws {
        let address = Address(street: "Main", city: "Bonn", tags: ["home"], moved: Date(timeIntervalSince1970: 10))
        try roundTrip(address, expected: .map([
            "street": .string("Main"),
            "city": .string("Bonn"),
            "tags": .list([.string("home")]),
            "moved": .double(10),
        ]))
        // Missing optional values are omitted
        #expect(try Address(street: "A", city: "B").soilValue.mapValue?["moved"] == nil)
        // Invalid data fails to decode
        #expect(Address(soilValue: .map(["street": .integer(1)])) == nil)
        // Paths in `Codable` types are stored as `.path`
        try roundTrip(Link(target: ["a", "b"]), expected: .map(["target": .path(["a", "b"])]))
        // Other encoders represent paths as arrays of strings
        let json = try JSONEncoder().encode(Link(target: ["a", "b"]))
        #expect(String(decoding: json, as: UTF8.self) == #"{"target":["a","b"]}"#)
        #expect(try JSONDecoder().decode(Link.self, from: json) == Link(target: ["a", "b"]))
    }

    @Test("Value is Codable")
    func valueCodable() throws {
        let value: Value = .map([
            "null": .null,
            "int": .integer(3),
            "double": .double(1.5),
            "string": .string("a"),
            "data": .data(Data([1, 2])),
            "path": .path(["a", "b"]),
            "list": .list([.string("a"), .string("b")]),
        ])
        // Other coders use a tagged representation which preserves the type
        let json = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(Value.self, from: json) == value)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(String(decoding: try encoder.encode(Value.integer(3)), as: UTF8.self) == #"["integer",3]"#)
        #expect(String(decoding: try encoder.encode(Value.null), as: UTF8.self) == #"["null"]"#)
        #expect(String(decoding: try encoder.encode(Value.list([.string("a")])), as: UTF8.self) == #"["list",[["string","a"]]]"#)
        // Values inside `Codable` types are stored directly by the SOIL coders
        #expect(try ValueEncoder().encode(value) == value)
        #expect(try ValueDecoder().decode(Value.self, from: value) == value)
        #expect(try ValueEncoder().encode(["a": value]) == .map(["a": value]))
    }

    @Test("Literals")
    func literals() {
        #expect(Value(nilLiteral: ()) == .null)
        let values: [Value] = [1, 2.5, true, "a", [1, "b"], ["k": 1]]
        #expect(values == [
            .integer(1),
            .double(2.5),
            .integer(1),
            .string("a"),
            .list([.integer(1), .string("b")]),
            .map(["k": .integer(1)]),
        ])
    }

    @Test("Receiver and provider")
    func receiverAndProvider() async throws {
        let storage = InMemoryStorage()
        let address = Address(street: "Main", city: "Bonn")

        try await storage.accept(address, for: ["address"]).wait()
        try await storage.accept(Priority.high, for: ["priority"]).wait()
        await storage.accept(42, for: ["answer"]).wait()

        #expect(await storage.currentValue(for: ["address"], as: Address.self) == address)
        #expect(await storage.currentValue(for: ["priority"], as: Priority.self) == .high)
        #expect(await storage.currentValue(for: ["answer"]) == .integer(42))
        #expect(await storage.currentValue(for: ["answer"], as: String.self) == nil)
        #expect(throws: EncodingError.self) { try storage.accept(UInt64.max, for: ["big"]) }
    }

    @Test("Typed values in a range")
    func typedValues() async throws {
        let storage = InMemoryStorage()
        let path: Path = ["value"]
        await storage.accept(1, for: path, at: Date(timeIntervalSince1970: 1)).wait()
        await storage.accept("a", for: path, at: Date(timeIntervalSince1970: 2)).wait()
        await storage.accept(3, for: path, at: Date(timeIntervalSince1970: 3)).wait()

        let values = await storage.values(for: path, as: Int.self)
        #expect(values.map(\.value) == [1, 3])
        #expect(values.map(\.timestamp) == [Date(timeIntervalSince1970: 1), Date(timeIntervalSince1970: 3)])
    }

    @Test("Samples and trees")
    func samplesAndTrees() throws {
        let sample = try Sample(value: Priority.low)
        #expect(sample.value == .integer(0))
        #expect(sample.value(as: Priority.self) == .low)
        #expect(sample.value(as: String.self) == nil)

        let tree = try ImmutableSampleTree(value: ["a", "b"] as Set<String>)
        #expect(tree.currentValue(as: Set<String>.self) == ["a", "b"])

        let message = try Message.value(Priority.high, for: ["p"])
        #expect(message.data.currentValue == .integer(1))
    }

    @Test("Storage nodes")
    func storageNodes() async throws {
        let storage = InMemoryStorage()
        let node = storage.node(at: ["node"])

        await node.set(1).wait()
        #expect(await node.value() == .integer(1))
        #expect(await node.value(as: Bool.self) == true)

        // Array literals are values, paths are stored as `.path`
        await node.set(["a", "b"]).wait()
        #expect(await node.value() == .list([.string("a"), .string("b")]))
        let path: Path = ["a", "b"]
        await node.set(path).wait()
        #expect(await node.value() == .path(["a", "b"]))
        try await node.valueNode(as: Path.self).set(path).wait()
        #expect(await node.value() == .path(["a", "b"]))

        let typed = node.valueChild(named: "priority", as: Priority.self)
        #expect(typed.path == ["node", "priority"])
        try await typed.set(.high).wait()
        #expect(await typed.value() == .high)

        await typed.setNull().wait()
        #expect(await typed.value() == nil)
        #expect(await storage.currentValue(for: ["node", "priority"]) == .null)
    }
}
