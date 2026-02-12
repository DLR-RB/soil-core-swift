import Testing
import Foundation
@testable import Soil

@Suite("JsonEncoding Compatibility Tests")
struct JsonEncodingTests {

    /// Round-trip assertion helper
    private func assertRoundTrip(
        _ message: Message
    ) throws {
        let encoder = JsonEncoding()

        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        #expect(decoded == message)
    }

    // MARK: - Fixtures


    private func sample(
        _ time: TimeInterval,
        _ value: Value
    ) -> Sample {
        Sample(
            value: value,
            timestamp: Date(timeIntervalSince1970:time)
        )
    }

    // MARK: - Minimal

    @Test("Minimal message")
    func minimal() throws {
        let message = Message(
            type: .data,
            path: ["root"]
        )

        try assertRoundTrip(message)
    }

    // MARK: - MessageType Coverage

    @Test("All MessageType values")
    func messageTypes() throws {
        for type in MessageType.allCases {
            let message = Message(
                type: type,
                path: ["type", "\(type.rawValue)"]
            )

            try assertRoundTrip(message)
        }
    }

    // MARK: - Value Cases

    @Test("Value.null")
    func valueNull() throws {
        let message = Message(
            type: .data,
            path: ["null"],
            value: .null
        )

        try assertRoundTrip(message)
    }

    @Test("Value.integer")
    func valueInteger() throws {
        let message = Message(
            type: .data,
            path: ["int"],
            value: .integer(123)
        )

        try assertRoundTrip(message)
    }

    @Test("Value.double")
    func valueDouble() throws {
        let message = Message(
            type: .data,
            path: ["double"],
            value: .double(123.456)
        )

        try assertRoundTrip(message)
    }

    @Test("Value.string")
    func valueString() throws {
        let message = Message(
            type: .data,
            path: ["string"],
            value: .string("Hello JSON 🌍")
        )

        try assertRoundTrip(message)
    }

    @Test("Value.data")
    func valueData() throws {
        let data = Data([0x00, 0x01, 0xFE, 0xFF])

        let message = Message(
            type: .data,
            path: ["blob"],
            value: .data(data)
        )

        try assertRoundTrip(message)
    }

    @Test("Value.path")
    func valuePath() throws {
        let message = Message(
            type: .data,
            path: ["outer"],
            value: .path(["inner", "leaf"])
        )

        try assertRoundTrip(message)
    }

    // MARK: - Path Edge Cases

    @Test("Empty path")
    func emptyPath() throws {
        let message = Message(
            type: .data,
            path: []
        )

        try assertRoundTrip(message)
    }

    @Test("Deep path")
    func deepPath() throws {
        let message = Message(
            type: .data,
            path: ["a","b","c","d","e","f","g"]
        )

        try assertRoundTrip(message)
    }

    @Test("Path with unicode")
    func unicodePath() throws {
        let message = Message(
            type: .data,
            path: ["ä","測試","🚀"]
        )

        try assertRoundTrip(message)
    }

    // MARK: - Timestamps

    @Test("Primary timestamp")
    func primaryTimestamp() throws {
        let message = Message(
            type: .data,
            path: ["time"],
            time: Date(timeIntervalSince1970:1_700_000_000.123)
        )

        try assertRoundTrip(message)
    }

    @Test("End timestamp")
    func endTimestamp() throws {
        let message = Message(
            type: .data,
            path: ["end"],
            end: Date(timeIntervalSince1970:1_800_000_000.999)
        )

        try assertRoundTrip(message)
    }

    // MARK: - Samples

    @Test("Single sample")
    func singleSample() throws {
        let message = Message(
            type: .data,
            path: ["samples"],
            samples: [
                sample(1_700_000_000, .integer(1))
            ]
        )

        try assertRoundTrip(message)
    }

    @Test("Multiple samples")
    func multipleSamples() throws {
        let message = Message(
            type: .data,
            path: ["samples"],
            samples: [
                sample(1, .integer(1)),
                sample(2, .double(2.5)),
                sample(3, .string("three")),
                sample(4, .null)
            ]
        )

        try assertRoundTrip(message)
    }

    @Test("Empty samples array")
    func emptySamples() throws {
        let message = Message(
            type: .data,
            path: ["samples"],
            samples: []
        )

        try assertRoundTrip(message)
    }

    // MARK: - Numeric Optionals

    @Test("Count / depth / id")
    func numericOptionals() throws {
        let message = Message(
            type: .request,
            path: ["nums"],
            count: 10,
            depth: 5,
            id: 999
        )

        try assertRoundTrip(message)
    }

    // MARK: - Fully Populated

    @Test("Fully populated message")
    func fullMessage() throws {
        let message = Message(
            type: .subscriptionInclusion,
            path: ["full","message"],
            value: .string("payload"),
            time: Date(timeIntervalSince1970:1_700_000_000),
            samples: [
                sample(10, .integer(10)),
                sample(20, .integer(20))
            ],
            count: 2,
            depth: 1,
            end: Date(timeIntervalSince1970:1_700_000_100),
            id: 12345
        )

        try assertRoundTrip(message)
    }

    // MARK: - Edge Values

    @Test("Large integers")
    func largeIntegers() throws {
        let message = Message(
            type: .data,
            path: ["large"],
            value: .integer(Int.max),
            count: Int.max,
            depth: Int.max,
            id: Int.max
        )

        try assertRoundTrip(message)
    }

    @Test("Negative integers")
    func negativeIntegers() throws {
        let message = Message(
            type: .data,
            path: ["negative"],
            value: .integer(-123),
            count: -1,
            depth: -5,
            id: -999
        )

        try assertRoundTrip(message)
    }

    @Test("High precision double")
    func precisionDouble() throws {
        let message = Message(
            type: .data,
            path: ["precision"],
            value: .double(0.1234567890123456)
        )

        try assertRoundTrip(message)
    }

    // MARK: - Batch Round-Trip

    @Test("Multiple messages round-trip")
    func multipleMessages() throws {
        let messages: [Message] = [
            Message(type: .data, path: ["a"]),
            Message(type: .request, path: ["b"], value: .integer(1)),
            Message(type: .deletionRequest, path: ["c"], value: .null),
            Message(
                type: .subscriptionDeletion,
                path: ["d"],
                samples: [sample(1, .integer(1))]
            )
        ]

        let codec = JsonEncoding()

        for message in messages {
            let data = try codec.encode(message)
            let decoded = try codec.decode(data)

            #expect(decoded == message)
        }
    }
}
