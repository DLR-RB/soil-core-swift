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
        if decoded != value {
            #expect(decoded == value)
            print(String(data: encoded, encoding: .utf8) ?? "Invalid encoding")
        }
    }

    private func encodeAndDecode<T>(_ type: T.Type, all: () -> [T]) throws where T: Equatable, T: Codable {
        for value in all() {
            try encodeAndDecode(value)
        }
    }

    @Test("Message Type")
    func testMessageType() throws {
        try encodeAndDecode(MessageType.self) { [
            .data,
            .request,
            .deletionRequest,
            .subscriptionDeletion,
            .subscriptionInclusion,
            .subscriptionExclusion
        ] }
    }

    @Test("Value Type")
    func testValueType() throws {
        try encodeAndDecode(ValueType.self) { [
            .null,
            .data,
            .integer,
            .double,
            .string,
            .path
        ] }
    }
}
