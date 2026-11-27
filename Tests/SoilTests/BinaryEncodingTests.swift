import Testing
import Foundation
@testable import Soil

@Suite("Binary Message Encoding")
struct BinaryMessageEncodingTests {

    private static let time = Timestamp(timeIntervalSince1970: 1_700_000_000.125)

    /// The big endian bytes of `time`
    private static let timeBytes: [UInt8] = [0x41, 0xD9, 0x54, 0xFC, 0x40, 0x08, 0x00, 0x00]

    private let encoding = BinaryMessageEncoding()

    private func check(_ message: Message, _ expected: [UInt8]) throws {
        let encoded = try encoding.encode(message)
        #expect(encoded == Data(expected), "\(encoded.map { String(format: "%02X", $0) }.joined(separator: " "))")
        #expect(try encoding.decode(Data(expected)) == message)
    }

    @Test("Wire format")
    func wireFormat() throws {
        // Example from the specification: Non-timestamped value at the root path
        try check(.value(.integer(42), for: []), [0x00, 0x00, 0x01, 0x01, 0x54])
        // Data message with id, count, path and a timestamped sample
        try check(.value(.string("x"), for: ["a"], at: Self.time, inResponseTo: 3, withCount: 2),
                  [0x18, 0x03, 0x02, 0x01, 0x01, 0x61, 0x01, 0x83] + Self.timeBytes + [0x01, 0x78])
        // Acknowledgement with a message timestamp, but no samples
        try check(.acknowledge(5, to: ["a"], timestamp: Self.time),
                  [0x12, 0x05] + Self.timeBytes + [0x01, 0x01, 0x61, 0x00])
        // Tree with children, sorted by name
        try check(.tree(ImmutableSampleTree(children: [
            "b": ImmutableSampleTree(value: .null),
            "a": ImmutableSampleTree(value: .double(1)),
        ]), for: []), [0x00, 0x00, 0x20, 0x01, 0x61, 0x01, 0x02, 0x3F, 0xF0, 0, 0, 0, 0, 0, 0, 0x01, 0x62, 0x01, 0x00])
        // Request with all fields
        try check(.request(["s"], from: Self.time, to: Self.time, limit: 4, depth: 1, id: 7),
                  [0x3F, 0x07, 0x04, 0x01] + Self.timeBytes + Self.timeBytes + [0x01, 0x01, 0x73])
        try check(.delete(["s"], depth: 0), [0x44, 0x00, 0x01, 0x01, 0x73])
        try check(.include([]), [0x60, 0x00])
        try check(.exclude(["a", "b"], depth: 2), [0x84, 0x02, 0x02, 0x01, 0x61, 0x01, 0x62])
        try check(.deleteRules(at: []), [0xA0, 0x00])
    }

    @Test("Examples from the specification")
    func specificationExamples() throws {
        try check(.value(.double(1.5), for: ["a"], at: Self.time),
                  [0x00, 0x01, 0x01, 0x61, 0x01, 0x82] + Self.timeBytes + [0x3F, 0xF8, 0, 0, 0, 0, 0, 0])
        try check(.tree(ImmutableSampleTree(children: [
            "a": ImmutableSampleTree(value: .integer(1)),
            "b": ImmutableSampleTree(value: .null),
        ]), for: []), [0x00, 0x00, 0x20, 0x01, 0x61, 0x01, 0x01, 0x02, 0x01, 0x62, 0x01, 0x00])
        try check(.request(["sensor"], depth: 2, id: 7), [0x34, 0x07, 0x02, 0x01, 0x06, 0x73, 0x65, 0x6E, 0x73, 0x6F, 0x72])
        #expect(try BinaryValueEncoding().encodeContent(of: .map(["a": .integer(123)])) == Data([0x01, 0x01, 0x61, 0x01, 0xF6, 0x01]))
        #expect(try BinaryValueEncoding().encodeContent(of: .list([.string("a"), .integer(123)])) == Data([0x02, 0x03, 0x01, 0x61, 0x01, 0xF6, 0x01]))
        #expect(try BinaryValueEncoding().encode(.integer(123)) == Data([0x01, 0xF6, 0x01]))
    }

    @Test("Extended counts in tree nodes")
    func extendedCounts() throws {
        let samples = (0..<15).map { Sample(value: .integer($0)) }
        let children = Dictionary(uniqueKeysWithValues: (0..<20).map { ("\($0)", ImmutableSampleTree() as any SampleTree) })
        let message = Message.tree(ImmutableSampleTree(samples: samples, children: children), for: [])
        let encoded = try encoding.encode(message)
        #expect(Array(encoded.prefix(5)) == [0x00, 0x00, 0xFF, 20, 15])
        #expect(try encoding.decode(encoded) == message)
    }

    @Test("Round trip")
    func roundTrip() throws {
        let messages: [Message] = [
            Message(type: .data, path: ["room", "light"], data: ImmutableSampleTree(value: .double(0.75), timestamp: Self.time), id: 4),
            Message(type: .data, path: ["a"], time: Self.time, data: ImmutableSampleTree(samples: [
                Sample(value: .integer(1), timestamp: Self.time),
                Sample(value: .data(Data([1, 2, 3])), timestamp: Self.time.addingTimeInterval(1)),
                Sample(value: .double(.infinity)),
            ], children: [
                "b": ImmutableSampleTree(value: .list([.string("x"), .map(["k": .integer(2)])]), timestamp: Self.time, children: [
                    "ü": ImmutableSampleTree(value: .path(["a", "b"])),
                ]),
            ]), count: 2),
            Message(type: .data, path: [], data: ImmutableSampleTree(value: .integer(.min))),
            Message(type: .request, path: ["sensor"], depth: Int.max, id: -1),
        ] + JsonEncodingBenchmarkTests.messages
        for message in messages {
            #expect(try encoding.decode(encoding.encode(message)) == message)
        }
    }

    @Test("Negative count and depth are encoded as zero")
    func negativeCounts() throws {
        let decoded = try encoding.decode(encoding.encode(.request([], limit: -3, depth: -1)))
        #expect(decoded == .request([], limit: 0, depth: 0))
    }

    @Test("Unused header fields are encoded for all message types")
    func unusedHeaderFields() throws {
        for type in MessageType.allCases {
            let message = Message(type: type, path: ["a"], time: Self.time, count: 1, depth: 2, end: Self.time, id: 3)
            let encoded = try encoding.encode(message)
            #expect(encoded.first == type.binaryCode << 5 | 0x1F)
            #expect(try encoding.decode(encoded) == message)
        }
    }

    @Test("Data is only encoded in data messages")
    func dataOnlyInDataMessages() throws {
        let message = Message(type: .subscriptionInclusion, path: ["a"], data: ImmutableSampleTree(value: .integer(1)))
        #expect(try encoding.encode(message) == Data([0x60, 0x01, 0x01, 0x61]))
    }

    @Test("Non-finite timestamps are rejected")
    func nonFiniteTimestamps() {
        #expect(throws: EncodingError.self) {
            try encoding.encode(.request([], from: Timestamp(timeIntervalSince1970: .infinity)))
        }
        let infinity: [UInt8] = [0x7F, 0xF0, 0, 0, 0, 0, 0, 0]
        #expect(throws: DecodingError.self) {
            try encoding.decode(Data([0x22] + infinity + [0x00]))
        }
    }

    @Test("Decoding errors", arguments: [
        [],                              // Missing header
        [0xC0, 0x00],                    // Unknown message type
        [0x00],                          // Missing path
        [0x00, 0x00],                    // Missing tree
        [0x00, 0x00, 0x01, 0x08],        // Unknown value type
        [0x00, 0x00, 0x01, 0x81, 0x00],  // Timestamp too short
        [0x00, 0x00, 0x10],              // Missing child
        [0x00, 0x00, 0x00, 0x00],        // Trailing bytes
        [0x10, 0x80, 0x00],              // Truncated id
        [0x00, 0x00, 0xF0, 0xFF, 0xFF],  // Invalid extended count
        [0x00, 0x00] + Array(repeating: [0x10, 0x00], count: 600).flatMap { $0 } + [0x00], // Nested too deeply
    ] as [[UInt8]])
    func decodingErrors(bytes: [UInt8]) {
        #expect(throws: DecodingError.self) {
            try encoding.decode(Data(bytes))
        }
    }
}
