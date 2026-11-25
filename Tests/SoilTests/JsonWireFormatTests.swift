import Testing
import Foundation
@testable import Soil

@Suite("JSON Wire Format")
struct JsonWireFormatTests {

    private static let time = Timestamp(timeIntervalSince1970: 1_700_000_000.125)

    /// Messages with their encoding in the standard and compact format, as produced by the previous `Codable` implementation
    static let fixtures: [(message: Message, standard: String, compact: String)] = [
        (
            Message(type: .data, path: ["room", "light"], data: ImmutableSampleTree(value: .double(0.75), timestamp: time), id: 4),
            #"{"id":4,"value":0.75,"path":["room","light"],"time":1700000000.125}"#,
            #"{"i":4,"p":["room","light"],"t":1700000000.125,"v":0.75}"#
        ),
        (
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(samples: [
                Sample(value: .integer(1), timestamp: time),
                Sample(value: .data(Data([1, 2, 3])), timestamp: time.addingTimeInterval(1)),
            ], children: [
                "b": ImmutableSampleTree(value: .list([.string("x"), .map(["k": .integer(2)])]), timestamp: time),
            ]), count: 2),
            #"{"path":["a"],"count":2,"samples":[{"type":"integer","time":1700000000.125,"value":1},{"type":"data","time":1700000001.125,"value":"AQID"}],"children":{"b":{"type":"list","value":["string","x","map",["k","integer",2]],"time":1700000000.125}}}"#,
            #"{"p":["a"],"s":[{"h":1,"v":1,"t":1700000000.125},{"h":4,"v":"AQID","t":1700000001.125}],"n":{"b":{"t":1700000000.125,"h":6,"v":[3,"x",7,["k",1,2]]}},"c":2}"#
        ),
        (
            Message(type: .request, path: ["sensor"], time: time, depth: 2, end: time.addingTimeInterval(60), id: 7),
            #"{"message":"read","path":["sensor"],"id":7,"depth":2,"time":1700000000.125,"end":1700000060.125}"#,
            #"{"d":2,"p":["sensor"],"i":7,"t":1700000000.125,"e":1700000060.125,"m":1}"#
        ),
        (
            Message(type: .data, path: ["link"], data: ImmutableSampleTree(samples: [
                Sample(value: .path(["room", "light"]), timestamp: nil),
            ], children: [
                "list": ImmutableSampleTree(value: .list([.path(["a", "b"]), .path([])])),
            ])),
            #"{"path":["link"],"value":["room","light"],"children":{"list":{"type":"list","value":["path",["a","b"],"path",[]]}}}"#,
            #"{"p":["link"],"v":["room","light"],"n":{"list":{"h":6,"v":[5,["a","b"],5,[]]}}}"#
        ),
    ]

    private func check(_ encoding: some MessageEncoding, message: Message, expected: String) throws {
        let encoded = try encoding.encode(message)
        // Key order is not significant, so compare the parsed JSON
        let object = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        let expectedObject = try JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary
        #expect(object != nil)
        #expect(object == expectedObject, "\(String(decoding: encoded, as: UTF8.self))")
        #expect(try encoding.decode(Data(expected.utf8)) == message)
    }

    @Test("Standard format is unchanged")
    func standardFormat() throws {
        for fixture in Self.fixtures {
            try check(JsonEncoding(), message: fixture.message, expected: fixture.standard)
        }
    }

    @Test("Compact format is unchanged")
    func compactFormat() throws {
        for fixture in Self.fixtures {
            try check(CompactJsonEncoding(), message: fixture.message, expected: fixture.compact)
        }
    }

    @Test("Round trip of special values")
    func specialValues() throws {
        let messages: [Message] = [
            Message(type: .data, path: [], data: ImmutableSampleTree(value: .integer(.min), timestamp: Self.time)),
            Message(type: .data, path: ["ü/ñ", "with \"quotes\"", "back\\slash", "tab\tnew\nline\u{01}"],
                    data: ImmutableSampleTree(value: .string("Emoji 😀, Umlaut ä, control \u{1F}"), timestamp: Self.time)),
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .double(-1.5e-300))),
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .double(1e20))),
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .double(2))),
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .data(Data()))),
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .list([]))),
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .map([:]))),
        ] + JsonEncodingBenchmarkTests.messages
        for encoding in [JsonEncoding() as any MessageEncoding, CompactJsonEncoding()] {
            for message in messages {
                #expect(try encoding.decode(encoding.encode(message)) == message)
            }
        }
    }

    // MARK: Decoding of foreign JSON

    private func decode(_ json: String) throws -> Message {
        try JsonEncoding().decode(Data(json.utf8))
    }

    private func value(_ json: String) throws -> Value? {
        try decode(json).data.samples.first?.value
    }

    @Test("Type after value")
    func typeAfterValue() throws {
        #expect(try value(#"{"value": 5, "type": "integer"}"#) == .integer(5))
        #expect(try value(#"{"value": "AQI=", "type": "data"}"#) == .data(Data([1, 2])))
        #expect(try value(#"{"value": ["k", "integer", 1], "type": "map"}"#) == .map(["k": .integer(1)]))
        #expect(try value(#"{"value": ["integer", 1], "type": "list"}"#) == .list([.integer(1)]))
        #expect(try value(#"{"value": ["a", "b"], "type": "path"}"#) == .path(["a", "b"]))
        // Lists and maps are always typed, so an untyped array is a path
        #expect(try value(#"{"value": ["a", "b"]}"#) == .path(["a", "b"]))
    }

    @Test("Whitespace and unknown keys")
    func whitespaceAndUnknownKeys() throws {
        let message = try decode("""
            {
              "unknown" : { "nested": [1, 2.5, true, false, null, "x"] },
              "path" : [ "a" , "b" ],
              "value" : 1.5 , "time" : 10
            }
            """)
        #expect(message == Message(type: .data, path: ["a", "b"], data: ImmutableSampleTree(value: .double(1.5), timestamp: .init(timeIntervalSince1970: 10))))
    }

    @Test("String escapes")
    func stringEscapes() throws {
        #expect(try value(#"{"value": "é😀\/\b\f\n\r\t\"\\"}"#) == .string("é😀/\u{08}\u{0C}\n\r\t\"\\"))
    }

    @Test("Integers")
    func integers() throws {
        #expect(try value(#"{"value": 9223372036854775807, "type": "integer"}"#) == .integer(.max))
        #expect(try value(#"{"value": -9223372036854775808, "type": "integer"}"#) == .integer(.min))
        #expect(try value(#"{"value": 3.0, "type": "integer"}"#) == .integer(3))
        #expect(throws: DecodingError.self) { try decode(#"{"value": 3.5, "type": "integer"}"#) }
    }

    @Test("Null in lists and maps")
    func nullInContainers() throws {
        let message = Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .list([.null, .map(["x": .null]), .integer(1)])))
        for encoding in [JsonEncoding() as any MessageEncoding, CompactJsonEncoding()] {
            #expect(try encoding.decode(encoding.encode(message)) == message)
        }
    }

    @Test("Invalid JSON", arguments: [
        "",
        "{",
        "[]",
        #"{"value": }"#,
        #"{"value": 1,}"#,
        #"{"value": 1} x"#,
        #"{"value": {}}"#,
        #"{"value": "unterminated}"#,
        #"{"value": "\ud83d"}"#,
        #"{"value": "\x"}"#,
        #"{"value": 1.2.3}"#,
        #"{"value": -}"#,
        #"{"value": .5}"#,
        #"{"value": 1, "type": "unknown"}"#,
        #"{"message": "unknown"}"#,
        #"{"type": null}"#,
        #"{"type": "integer"}"#,
        #"{"samples": [{"type": "string"}]}"#,
        #"{"value": true, "type": "double"}"#,
        #"{"path": {}}"#,
        #"{"path": [1]}"#,
        #"{"value": ["integer"], "type": "list"}"#,
        #"{"value": ["integer", 1]}"#,
        #"{"value": ["k", "integer", 1], "type": "map", "extra": [}"#,
    ])
    func invalidJson(_ json: String) {
        #expect(throws: DecodingError.self) { try decode(json) }
    }

    @Test("Deep nesting is rejected")
    func deepNesting() {
        let depth = 100_000
        let json = #"{"value": "# + String(repeating: #"["list","#, count: depth) + "null" + String(repeating: "]", count: depth) + "}"
        #expect(throws: DecodingError.self) { try decode(json) }
    }

    // MARK: Samples and timestamps

    @Test("Samples without timestamps")
    func samplesWithoutTimestamps() throws {
        let message = Message(type: .data, path: ["a"], data: ImmutableSampleTree(samples: [
            Sample(value: .integer(1), timestamp: Self.time),
            Sample(value: .integer(2)),
            Sample(value: .null),
        ], children: [
            "b": ImmutableSampleTree(samples: [Sample(value: .string("x")), Sample(value: .double(1.5))]),
        ]))
        for encoding in Self.encodings {
            #expect(try encoding.decode(encoding.encode(message)) == message)
        }
        // Missing timestamps are not replaced with the current time
        let decoded = try decode(#"{"samples": [{"value": 1}, {"value": 2, "time": 3}], "value": 4}"#)
        #expect(decoded == Message(type: .data, path: [], data: ImmutableSampleTree(samples: [
            Sample(value: .double(2), timeIntervalSince1970: 3),
            Sample(value: .double(1)),
            Sample(value: .double(4)),
        ])))
    }

    @Test("Top-level time only applies to the top-level value")
    func topLevelTime() throws {
        let decoded = try decode(#"{"time": 5, "value": 1, "samples": [{"value": 2}]}"#)
        #expect(decoded.time == nil)
        #expect(decoded.data.samples == [Sample(value: .double(1), timeIntervalSince1970: 5), Sample(value: .double(2))])
    }

    @Test("Timestamp of data messages")
    func dataMessageTime() throws {
        let other = Self.time.addingTimeInterval(1)
        let messages = [
            Message.acknowledge(1, to: ["a"], timestamp: Self.time),
            Message(type: .data, path: ["a"], time: Self.time, data: ImmutableSampleTree(value: .integer(1), timestamp: other)),
            Message(type: .data, path: ["a"], time: Self.time, data: ImmutableSampleTree(value: .integer(1))),
            Message(type: .data, path: ["a"], time: Self.time, data: ImmutableSampleTree(samples: [
                Sample(value: .integer(1), timestamp: other),
                Sample(value: .integer(2)),
            ], children: [
                "b": ImmutableSampleTree(value: .integer(3), timestamp: other),
            ])),
        ]
        for encoding in Self.encodings {
            for message in messages {
                #expect(try encoding.decode(encoding.encode(message)) == message)
            }
        }
        // The single sample is moved to the samples, so that the time can be used for the message
        let encoded = try JSONSerialization.jsonObject(with: JsonEncoding().encode(messages[1])) as? NSDictionary
        #expect(encoded?["value"] == nil)
        #expect((encoded?["samples"] as? NSArray)?.count == 1)
        #expect(encoded?["time"] as? Double == Self.time.timeIntervalSince1970)
    }

    @Test("Null samples")
    func nullSamples() throws {
        let time = Timestamp(timeIntervalSince1970: 5)
        #expect(try decode(#"{"value": null}"#).data.samples == [Sample(value: .null)])
        #expect(try decode(#"{"type": "null"}"#).data.samples == [Sample(value: .null)])
        #expect(try decode(#"{"type": "null", "value": null, "time": 5}"#).data.samples == [Sample(value: .null, timestamp: time)])
        #expect(try decode(#"{"samples": [{"value": null, "time": 5}, {"type": "null"}]}"#).data.samples == [Sample(value: .null, timestamp: time), Sample(value: .null)])
        // A time without value or type is the timestamp of the message, or ignored in nodes and samples
        #expect(try decode(#"{"time": 5}"#) == Message(type: .data, path: [], time: time))
        #expect(try decode(#"{"time": 5, "value": 1}"#).time == nil)
        #expect(try decode(#"{"children": {"x": {"time": 5}}}"#).data.children["x"]?.samples.isEmpty == true)
        #expect(try decode(#"{"samples": [{"time": 5}, {}, {"value": 1}]}"#).data.samples == [Sample(value: .double(1))])
        // Nodes without value and type have no samples
        #expect(try decode(#"{"children": {"x": {}}}"#).data.children["x"]?.samples.isEmpty == true)
        #expect(try decode(#"{"path": ["a"]}"#).data.samples.isEmpty)
    }

    // MARK: Message types

    @Test("Data is ignored in other messages")
    func dataInOtherMessages() throws {
        let expected = Message(type: .request, path: ["a"], time: .init(timeIntervalSince1970: 3), id: 1)
        // Message type before and after the data fields
        #expect(try decode(#"{"message": "read", "path": ["a"], "id": 1, "time": 3, "value": 1, "type": "integer", "samples": [{"value": 2}], "children": {"b": {"value": 3}}}"#) == expected)
        #expect(try decode(#"{"path": ["a"], "id": 1, "time": 3, "value": 1, "type": "integer", "samples": [{"value": 2}], "children": {"b": {"value": 3}}, "message": "read"}"#) == expected)
        // Data is not encoded
        let message = Message(type: .request, path: ["a"], time: .init(timeIntervalSince1970: 3), data: ImmutableSampleTree(value: .integer(1)), id: 1)
        for encoding in Self.encodings {
            #expect(try encoding.decode(encoding.encode(message)) == expected)
        }
    }

    @Test("Negative and large count and depth are clamped")
    func clampedCountAndDepth() throws {
        let message = try decode(#"{"message": "read", "count": -5, "depth": -9223372036854775809}"#)
        #expect(message.count == 0)
        #expect(message.depth == 0)
        let large = try decode(#"{"message": "read", "count": 9223372036854775808, "depth": 1e30}"#)
        #expect(large.count == .max)
        #expect(large.depth == .max)
    }

    // MARK: Values

    @Test("Single component paths as strings")
    func singleComponentPaths() throws {
        #expect(try decode(#"{"path": "a"}"#).path == ["a"])
        #expect(try value(#"{"value": "a", "type": "path"}"#) == .path(["a"]))
        #expect(try value(#"{"type": "path", "value": "a"}"#) == .path(["a"]))
        #expect(try value(#"{"type": "list", "value": ["path", "a", "path", ["b", "c"]]}"#) == .list([.path(["a"]), .path(["b", "c"])]))
        // Without type, a string is a string
        #expect(try value(#"{"value": "a"}"#) == .string("a"))
    }

    @Test("Booleans are decoded as integers")
    func booleans() throws {
        #expect(try value(#"{"value": true}"#) == .integer(1))
        #expect(try value(#"{"value": false}"#) == .integer(0))
        #expect(try value(#"{"value": true, "type": "integer"}"#) == .integer(1))
        #expect(try value(#"{"type": "list", "value": ["integer", false, "integer", true]}"#) == .list([.integer(0), .integer(1)]))
        let compact = try CompactJsonEncoding().decode(Data(#"{"v": true}"#.utf8))
        #expect(compact.data.samples.first?.value == .integer(1))
    }

    @Test("Duplicate map keys use the last value")
    func duplicateMapKeys() throws {
        #expect(try value(#"{"type": "map", "value": ["k", "integer", 1, "a", "null", null, "k", "string", "x"]}"#) == .map(["k": .string("x"), "a": .null]))
    }

    // MARK: Special doubles

    private static let encodings: [any MessageEncoding] = [JsonEncoding(), CompactJsonEncoding()]

    private func roundTrip(_ value: Value, encoding: any MessageEncoding) throws -> Value? {
        let message = Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: value))
        return try encoding.decode(encoding.encode(message)).data.samples.first?.value
    }

    /// Check that a value is a double with the same bit pattern (sign of zero, NaN), or the same value
    private func isSame(_ value: Value?, _ expected: Double) -> Bool {
        guard case .double(let double) = value else {
            return false
        }
        return expected.isNaN ? double.isNaN : double.bitPattern == expected.bitPattern
    }

    @Test("Non-finite doubles", arguments: [Double.nan, -.nan, .signalingNaN, .infinity, -.infinity])
    func nonFinite(_ double: Double) throws {
        for encoding in Self.encodings {
            #expect(isSame(try roundTrip(.double(double), encoding: encoding), double))
            // In lists and maps
            let list = try roundTrip(.list([.double(double), .string("nan")]), encoding: encoding)?.listValue
            #expect(isSame(list?.first, double))
            #expect(list?.last == .string("nan"))
            let map = try roundTrip(.map(["x": .double(double)]), encoding: encoding)?.mapValue
            #expect(isSame(map?["x"], double))
        }
    }

    @Test("Non-finite doubles in multiple samples")
    func nonFiniteSamples() throws {
        let message = Message(type: .data, path: ["a"], data: ImmutableSampleTree(samples: [
            Sample(value: .double(.infinity), timestamp: Self.time),
            Sample(value: .double(-.infinity), timestamp: Self.time.addingTimeInterval(1)),
        ]))
        for encoding in Self.encodings {
            #expect(try encoding.decode(encoding.encode(message)) == message)
        }
    }

    @Test("Wire format of non-finite doubles")
    func nonFiniteWireFormat() throws {
        let nan = Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .double(.nan)))
        let infinity = Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .list([.double(-.infinity)])))
        let cases: [(any MessageEncoding, Message, String)] = [
            (JsonEncoding(), nan, #"{"path":["a"],"type":"double","value":"nan"}"#),
            (CompactJsonEncoding(), nan, #"{"p":["a"],"h":2,"v":"nan"}"#),
            (JsonEncoding(), infinity, #"{"path":["a"],"type": "list","value":["double","-inf"]}"#),
            (CompactJsonEncoding(), infinity, #"{"p":["a"],"h":6,"v":[2,"-inf"]}"#),
        ]
        for (encoding, message, expected) in cases {
            let object = try JSONSerialization.jsonObject(with: encoding.encode(message)) as? NSDictionary
            let expectedObject = try JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary
            #expect(object != nil)
            #expect(object == expectedObject)
        }
    }

    @Test("Decoding of non-finite doubles")
    func nonFiniteDecoding() throws {
        #expect(isSame(try value(#"{"type": "double", "value": "inf"}"#), .infinity))
        #expect(isSame(try value(#"{"value": "-inf", "type": "double"}"#), -.infinity))
        #expect(isSame(try value(#"{"value": ["double", "nan"], "type": "list"}"#)?.listValue?.first, .nan))
        // Without type, the strings are not special
        #expect(try value(#"{"value": "nan"}"#) == .string("nan"))
        #expect(try value(#"{"value": ["string", "inf"], "type": "list"}"#) == .list([.string("inf")]))
        // Only the exact names are accepted
        for name in ["NaN", "Infinity", "+inf", "-nan", "", "1.5"] {
            #expect(throws: DecodingError.self) { try decode(#"{"type": "double", "value": "\#(name)"}"#) }
        }
    }

    @Test("Finite special doubles", arguments: [
        -0.0, 0.0, .leastNonzeroMagnitude, -.leastNonzeroMagnitude, .leastNormalMagnitude,
        .greatestFiniteMagnitude, -.greatestFiniteMagnitude, 1e20, 0.1 + 0.2, 2,
    ])
    func finiteSpecial(_ double: Double) throws {
        for encoding in Self.encodings {
            #expect(isSame(try roundTrip(.double(double), encoding: encoding), double))
        }
        // Finite values are encoded as JSON numbers without type
        let message = Message(type: .data, path: [], data: ImmutableSampleTree(value: .double(double)))
        let object = try JSONSerialization.jsonObject(with: JsonEncoding().encode(message)) as? NSDictionary
        #expect(object?["type"] == nil)
        #expect(object?["value"] is NSNumber)
    }

    @Test("Underflow decodes to zero")
    func underflow() throws {
        #expect(isSame(try value(#"{"value": 1e-400}"#), 0))
        #expect(isSame(try value(#"{"value": -1e-400}"#), -0.0))
    }

    // MARK: Out of range numbers

    @Test("Doubles too large are converted to infinity", arguments: [
        ("1e400", Double.infinity),
        ("-1e400", -Double.infinity),
        ("1.8e308", .infinity),
        ("123456789e999999999999", .infinity),
        ("1.7976931348623157e308", .greatestFiniteMagnitude),
        ("-1.7976931348623157e308", -.greatestFiniteMagnitude),
    ])
    func doubleOverflow(_ number: String, _ expected: Double) throws {
        // Without type, typed, and in lists and maps
        #expect(isSame(try value(#"{"value": \#(number)}"#), expected))
        #expect(isSame(try value(#"{"type": "double", "value": \#(number)}"#), expected))
        #expect(isSame(try value(#"{"value": ["double", \#(number)], "type": "list"}"#)?.listValue?.first, expected))
        #expect(isSame(try value(#"{"type": "map", "value": ["x", "double", \#(number)]}"#)?.mapValue?["x"], expected))
        let compact = try CompactJsonEncoding().decode(Data(#"{"h": 2, "v": \#(number)}"#.utf8))
        #expect(isSame(compact.data.samples.first?.value, expected))
    }

    @Test("Integers too large are clamped", arguments: [
        ("9223372036854775808", Int.max),
        ("-9223372036854775809", Int.min),
        ("99999999999999999999999999999999", .max),
        ("-99999999999999999999999999999999", .min),
        ("9.3e18", .max),
        ("-9.3e18", .min),
        ("9223372036854775807.0", .max), // Rounds to 2^63 as a double
        ("1e30", .max),
        ("-1e30", .min),
        ("1e400", .max),
        ("-1e400", .min),
        ("9223372036854775807", .max),
        ("-9223372036854775808", .min),
        ("4.5e15", 4_500_000_000_000_000),
    ])
    func integerOverflow(_ number: String, _ expected: Int) throws {
        #expect(try value(#"{"type": "integer", "value": \#(number)}"#) == .integer(expected))
        #expect(try value(#"{"value": ["integer", \#(number)], "type": "list"}"#) == .list([.integer(expected)]))
        #expect(try value(#"{"type": "map", "value": ["x", "integer", \#(number)]}"#) == .map(["x": .integer(expected)]))
        let compact = try CompactJsonEncoding().decode(Data(#"{"h": 1, "v": \#(number)}"#.utf8))
        #expect(compact.data.samples.first?.value == .integer(expected))
    }

    @Test("Integers with fractions are rejected", arguments: ["3.5", "-0.1", "1e-5"])
    func integerFraction(_ number: String) {
        #expect(throws: DecodingError.self) { try decode(#"{"type": "integer", "value": \#(number)}"#) }
    }

    @Test("Out of range numbers in message fields are rejected", arguments: [
        #"{"id": 1e30}"#,
        #"{"time": 1e400}"#,
        #"{"end": -1e400}"#,
        #"{"value": 1, "time": 1e400}"#,
        #"{"samples": [{"value": 1, "time": 1e400}, {"value": 2, "time": 1}]}"#,
    ])
    func messageFieldOverflow(_ json: String) {
        #expect(throws: DecodingError.self) { try decode(json) }
    }

    @Test("Out of range type identifiers are rejected", arguments: [
        #"{"m": 9223372036854775808}"#,
        #"{"h": 1e400, "v": 1}"#,
        #"{"v": [99999999999999999999, 1]}"#,
    ])
    func compactTagOverflow(_ json: String) {
        #expect(throws: DecodingError.self) { try CompactJsonEncoding().decode(Data(json.utf8)) }
    }

    @Test("Non-finite timestamps are rejected", arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteTimestamps(_ interval: Double) {
        let date = Timestamp(timeIntervalSince1970: interval)
        let messages = [
            Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .integer(1), timestamp: date)),
            Message(type: .request, path: ["a"], time: date),
            Message(type: .request, path: ["a"], end: date),
        ]
        for encoding in Self.encodings {
            for message in messages {
                #expect(throws: EncodingError.self) { try encoding.encode(message) }
            }
        }
    }
}
