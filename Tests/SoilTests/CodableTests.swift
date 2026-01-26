import Foundation
import Testing
import Soil

@Suite("Codable")
struct CodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func encodeAndDecode<T>(_ value: T) throws where T: Equatable, T: Codable {
        let encoded = try encoder.encode(value)
        let decoded = try decoder.decode(T.self, from: encoded)
        #expect(decoded == value)
    }

    private func encodeAndDecode<T>(_ type: T.Type, all: () -> [T]) throws where T: Equatable, T: Codable {
        for value in all() {
            try encodeAndDecode(value)
        }
    }

    @Test("Value")
    func testValue() throws {
        try encodeAndDecode(Value.self) { [
            .data(.init(repeating: 42, count: 12)),
            .integer(123),
            .double(3.14),
            .string("Test"),
            .path(["a", "b", "c"])
        ] }
    }

    @Test("ValueType")
    func testValueType() throws {
        try encodeAndDecode(ValueType.self) { [
            .data,
            .integer,
            .double,
            .string,
            .path
        ] }
    }

    @Test("Sample")
    func testSample() throws {
        try encodeAndDecode(Sample.self) { [
            .init(value: .data(.init(repeating: 42, count: 12))),
            .init(value: .integer(123)),
            .init(value: .double(3.14)),
            .init(value: .string("Test")),
            .init(value: .path(["a", "b", "c"]))
        ] }
    }

    @Test("Message")
    func testMessage() throws {
        try encodeAndDecode(Message.self) { [
            .value(.integer(123), for: ["a", "b", "c"], at: .current()),
            .value(.integer(234), for: []),
            .samples([
                .init(value: .integer(123), timestamp: .current().addingTimeInterval(-10000)),
                .init(value: .double(3.14), timestamp: .current().addingTimeInterval(-9000))
            ], for: ["zzz"]),
            .include(["abc"], with: 123, in: 234),
            .include(["", "some"], in: 123),
            .request(["Path"], to: .current(), depth: 0),
            .request(["Path"]),
            .request(["123"], from: .current().addingTimeInterval(-1000), to: .current(), limit: 100),
            .request(["123", "456"]),
            .exclude(["a", "a"], with: 10, from: 234),
            .exclude(["a", "a", "a"], from: 123)
        ] }
    }
}
