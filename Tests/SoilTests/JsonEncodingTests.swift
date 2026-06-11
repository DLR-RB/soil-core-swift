import Testing
import Foundation
@testable import Soil

@Suite("JsonEncoding Compatibility Tests")
struct JsonEncodingTests {

    /// Round-trip assertion helper
    private func assertRoundTrip(_ message: Message) throws {
        let encoder = JsonEncoding()

        let data = try encoder.encode(message)
        do {
            let decoded = try encoder.decode(data)

            #expect(decoded == message)
        } catch {
            print(String(data: data, encoding: .utf8) ?? "Invalid encoding")
            throw error
        }
    }

    private func assertRoundTrip(_ messages: [Message]) throws {
        for value in messages {
            try assertRoundTrip(value)
        }
    }

    // MARK: Fixtures

    private func sample(
        _ time: TimeInterval,
        _ value: Value
    ) -> Sample {
        Sample(
            value: value,
            timestamp: Date(timeIntervalSince1970:time)
        )
    }

    // MARK: Minimal

    @Test("Minimal message")
    func minimal() throws {
        let message = Message(
            type: .data,
            path: ["root"]
        )

        try assertRoundTrip(message)
    }

    // MARK: MessageType Coverage

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

    // MARK: Value Cases

    @Test("Value.null")
    func valueNull() throws {
        let message = Message.value(.null, for: ["null"])
        try assertRoundTrip(message)
    }

    @Test("Value.integer")
    func valueInteger() throws {
        let message = Message.value(.integer(123), for: ["int"])
        try assertRoundTrip(message)
    }

    @Test("Value.double")
    func valueDouble() throws {
        let message = Message.value(.double(123.456), for: ["double"])
        try assertRoundTrip(message)
    }

    @Test("Value.string")
    func valueString() throws {
        let message = Message.value(.string("Hello JSON 🌍"), for: ["string"])
        try assertRoundTrip(message)
    }

    @Test("Value.data")
    func valueData() throws {
        let data = Data([0x00, 0x01, 0xFE, 0xFF])
        let message = Message.value(.data(data), for: ["blob"])
        try assertRoundTrip(message)
    }

    @Test("Value.path")
    func valuePath() throws {
        let message = Message.value(.path(["inner", "leaf"]), for: ["outer"])
        try assertRoundTrip(message)
    }

    // MARK: Path Edge Cases

    @Test("Empty path")
    func emptyPath() throws {
        let message = Message(type: .data, path: [])
        try assertRoundTrip(message)
    }

    @Test("Deep path")
    func deepPath() throws {
        let message = Message(type: .data, path: ["a","b","c","d","e","f","g"])
        try assertRoundTrip(message)
    }

    @Test("Path with unicode")
    func unicodePath() throws {
        let message = Message(type: .data, path: ["ä","測試","🚀"])
        try assertRoundTrip(message)
    }

    // MARK: Timestamps

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

    // MARK: Samples

    @Test("Single sample")
    func singleSample() throws {
        let message = Message.samples(
            [
                sample(1_700_000_000, .integer(1))
            ],
            for: ["samples"]
        )

        try assertRoundTrip(message)
    }

    @Test("Multiple samples")
    func multipleSamples() throws {
        let message = Message.samples(
            [
                sample(1, .integer(1)),
                sample(2, .double(2.5)),
                sample(3, .string("three")),
                sample(4, .null)
            ],
            for: ["samples"]
        )

        try assertRoundTrip(message)
    }

    @Test("Empty samples array")
    func emptySamples() throws {
        let message = Message.samples(
            [],
            for: ["samples"]
        )

        try assertRoundTrip(message)
    }

    // MARK: Numeric Optionals

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

    // MARK: Fully Populated

    @Test("Fully populated message")
    func fullMessage() throws {
        let tree = ImmutableSampleTree(
            samples: [
                sample(10, .integer(10)),
                sample(20, .integer(20))
            ]
        )
        let message = Message(
            type: .subscriptionInclusion,
            path: ["full","message"],
            time: Date(timeIntervalSince1970:1_700_000_000),
            data: tree,
            count: 2,
            depth: 1,
            end: Date(timeIntervalSince1970:1_700_000_100),
            id: 12345
        )

        try assertRoundTrip(message)
    }

    // MARK: Edge Values

    @Test("Large integers")
    func largeIntegers() throws {
        let tree = ImmutableSampleTree(value: .integer(Int.max))
        let message = Message(
            type: .data,
            path: ["large"],
            data: tree,
            count: Int.max,
            depth: Int.max,
            id: Int.max
        )

        try assertRoundTrip(message)
    }

    @Test("Negative integers")
    func negativeIntegers() throws {
        let tree = ImmutableSampleTree(value: .integer(Int.min))
        let message = Message(
            type: .data,
            path: ["negative"],
            data: tree,
            count: -1,
            depth: -5,
            id: -999
        )

        try assertRoundTrip(message)
    }

    @Test("High precision double")
    func precisionDouble() throws {
        let message = Message.value(
            .double(0.1234567890123456),
            for: ["precision"]
        )

        try assertRoundTrip(message)
    }

    // MARK: Batch Round-Trip

    @Test("Multiple messages round-trip")
    func multipleMessages() throws {
        let messages: [Message] = [
            Message(type: .data, path: ["a"]),
            Message(type: .request, path: ["b"], data: ImmutableSampleTree(value: .integer(1))),
            Message(type: .deletionRequest, path: ["c"], data : ImmutableSampleTree(value: .null)),
            Message(
                type: .subscriptionDeletion,
                path: ["d"],
                data: ImmutableSampleTree(sample: sample(1, .integer(1)))
            )
        ]

        let codec = JsonEncoding()

        for message in messages {
            let data = try codec.encode(message)
            let decoded = try codec.decode(data)

            #expect(decoded == message)
        }
    }

    @Test("Various messages")
    func testMessage() throws {
        try assertRoundTrip([
            .value(.null, for: ["a", "b"]),
            .value(.integer(123), for: ["a", "b", "c"], at: .current()),
            .value(.integer(234), for: []),
            .samples([
                .init(value: .integer(123), timestamp: .current().addingTimeInterval(-10000)),
                .init(value: .double(3.14), timestamp: .current().addingTimeInterval(-9000))
            ], for: ["zzz"]),
            .include(["abc"], depth: 123),
            .include(["", "some"]),
            .request(["Path"], to: .current(), depth: 0),
            .request(["Path"]),
            .request(["123"], from: .current().addingTimeInterval(-1000), to: .current(), limit: 100),
            .request(["123", "456"]),
            .exclude(["a", "a"], depth: 10),
            .exclude(["a", "a", "a"])
        ])
    }

    // MARK: Standard messages

    @Test("All fields set")
    func testAllFieldsSet() throws {
        let message = Message(
            type: .data,
            path: ["some", "path"],
            time: .init(timeIntervalSince1970: 123),
            data: ImmutableSampleTree(
                samples: [
                    Sample(value: .double(111), timeIntervalSince1970: 222.0),
                    Sample(value: .integer(222), timeIntervalSince1970: 333)
                ],
                children: [
                    "child" : ImmutableSampleTree(sample: Sample(value: .string("333"), timeIntervalSince1970: 444)),
                    "other" : ImmutableSampleTree(samples: [
                        Sample(value: .data(Data(repeating: 42, count: 3)), timeIntervalSince1970: 555),
                        Sample(value: .path(["link", "there"]), timeIntervalSince1970: 666),
                        Sample(value: .null, timeIntervalSince1970: 777)
                    ])
                    ]
                ),
            count: 234,
            depth: 345,
            end: .init(timeIntervalSince1970: 456),
            id: 567)
        let raw = """
        {
            "type": "data",
            "path": ["some", "path"],
            "time": 123.0,
            "samples": [
                {
                    "value": 111.0,
                    "time": 222.0
                },
                {
                    "value": 222,
                    "valueType": "integer",
                    "time": 333.0
                }
            ],
            "children": {
                "child": {
                    "value": "333",
                    "time": 444
                },
                "other": {
                    "samples": [
                        {
                            "value": "Kioq",
                            "valueType": "data",
                            "time": 555.0
                        },
                        {
                            "value": ["link", "there"],
                            "time": 666.0
                        },
                        {
                            "value": null,
                            "time": 777.0
                        }
                    ]
                }
            },
            "count": 234,
            "depth": 345,
            "end": 456.0,
            "id": 567
        }
        """

        let encoded = raw.data(using: .utf8)!

        let encoder = JsonEncoding()
        let decoded = try encoder.decode(encoded)

        #expect(decoded == message)

        try assertRoundTrip(message)
    }
}
