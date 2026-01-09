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
}
