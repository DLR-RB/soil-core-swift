import Testing
import Foundation
@testable import Soil

/**
 Performance measurements for the JSON encodings.

 Run with `SOIL_BENCHMARK=1 swift test -c release --filter Benchmark`
 */
@Suite("JSON Encoding Benchmark", .enabled(if: ProcessInfo.processInfo.environment["SOIL_BENCHMARK"] != nil))
struct JsonEncodingBenchmarkTests {

    private let iterations = 20_000

    /// A representative mix of messages
    static let messages: [Message] = {
        let time = Timestamp(timeIntervalSince1970: 1_700_000_000.125)
        return [
            Message(type: .data, path: ["a", "b"], data: ImmutableSampleTree(value: .double(3.14), timestamp: time)),
            Message(type: .data, path: ["sensor", "temperature"], data: ImmutableSampleTree(value: .integer(21), timestamp: time)),
            Message(type: .data, path: ["device", "name"], data: ImmutableSampleTree(value: .string("Living room \"lamp\""), timestamp: time)),
            Message(type: .data, path: ["blob"], data: ImmutableSampleTree(value: .data(Data(repeating: 0xAB, count: 32)), timestamp: time)),
            Message(type: .data, path: ["history"], data: ImmutableSampleTree(samples: (0..<10).map {
                Sample(value: .double(Double($0) * 0.5), timestamp: time.addingTimeInterval(Double($0)))
            }, children: [:]), count: 10, id: 42),
            Message(type: .data, path: ["room"], data: ImmutableSampleTree(samples: [], children: [
                "light": ImmutableSampleTree(value: .list([.integer(1), .double(2.5), .string("x"), .null]), timestamp: time),
                "state": ImmutableSampleTree(value: .map(["on": .integer(1), "level": .double(0.75)]), timestamp: time),
                "meta": ImmutableSampleTree(samples: [], children: [
                    "id": ImmutableSampleTree(value: .string("abc"), timestamp: time)
                ])
            ])),
            Message(type: .request, path: ["sensor"], time: time, depth: 2, end: time.addingTimeInterval(60), id: 7),
            Message(type: .subscriptionInclusion, path: ["a", "b", "c"], depth: 3, id: 8),
            Message(type: .subscriptionExclusion, path: ["a"], depth: 1, id: 9),
        ]
    }()

    private func measure(_ name: String, _ encoding: some MessageEncoding) throws {
        let messages = Self.messages
        let encoded = try messages.map(encoding.encode)
        let bytes = encoded.reduce(0) { $0 + $1.count }

        let clock = ContinuousClock()
        var sink = 0
        let encodeDuration = try clock.measure {
            for _ in 0..<iterations {
                for message in messages {
                    sink &+= try encoding.encode(message).count
                }
            }
        }
        let decodeDuration = try clock.measure {
            for _ in 0..<iterations {
                for data in encoded {
                    sink &+= try encoding.decode(data).path.count
                }
            }
        }
        let count = Double(iterations * messages.count)
        let encodeTime = nanoseconds(encodeDuration) / count
        let decodeTime = nanoseconds(decodeDuration) / count
        print("\(name): \(bytes) bytes, encode \(Int(encodeTime)) ns/msg, decode \(Int(decodeTime)) ns/msg (\(sink))")
    }

    private func nanoseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1e9 + Double(duration.components.attoseconds) / 1e9
    }

    @Test("Benchmark")
    func benchmark() throws {
        try measure("JsonEncoding", JsonEncoding())
        try measure("CompactJsonEncoding", CompactJsonEncoding())
    }
}
