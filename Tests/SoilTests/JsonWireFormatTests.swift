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
            // Time set together with a single sample
            Message(type: .data, path: ["a"], time: Self.time, data: ImmutableSampleTree(value: .integer(1), timestamp: Self.time)),
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
        #expect(throws: DecodingError.self) { try decode(#"{"value": 9223372036854775808, "type": "integer"}"#) }
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
        #"{"value": true}"#,
        #"{"value": {}}"#,
        #"{"value": "unterminated}"#,
        #"{"value": "\ud83d"}"#,
        #"{"value": "\x"}"#,
        #"{"value": 1.2.3}"#,
        #"{"value": -}"#,
        #"{"value": .5}"#,
        #"{"value": 1, "type": "unknown"}"#,
        #"{"message": "unknown"}"#,
        #"{"samples": [{"value": 1}]}"#,
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

    @Test("Non-finite doubles are rejected")
    func nonFinite() {
        let message = Message(type: .data, path: ["a"], data: ImmutableSampleTree(value: .double(.nan)))
        #expect(throws: EncodingError.self) { try JsonEncoding().encode(message) }
    }
}
