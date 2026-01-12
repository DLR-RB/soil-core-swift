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
            .value(path: ["a", "b", "c"], value: .integer(123), timestamp: Date()),
            .value(path: [], value: .integer(234)),
            .values(path: ["zzz"], samples: [
                .init(value: .integer(123), timestamp: Date().addingTimeInterval(-10000)),
                .init(value: .double(3.14), timestamp: Date().addingTimeInterval(-9000))
            ]),
            .subscribe(path: ["abc"], depth: 123),
            .subscribe(path: ["", "some"]),
            .request(path: ["Path"], beforeOrAt: Date(), depth: 0),
            .request(path: ["Path"]),
            .history(path: ["123"], start: Date().addingTimeInterval(-1000), end: Date(), limit: 100),
            .history(path: ["123", "456"]),
            .exclude(path: ["a", "a"], depth: 10),
            .exclude(path: ["a", "a", "a"])
        ] }
    }
}
