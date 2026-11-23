import Foundation
import Testing
import Soil

/// The encodings to test
enum TestedValueEncoding: CaseIterable {
    case binary
    case json
    case compactJSON

    var encoding: any ValueEncoding {
        switch self {
        case .binary: BinaryValueEncoding()
        case .json: JSONValueEncoding()
        case .compactJSON: CompactJSONValueEncoding()
        }
    }
}

@Suite("Value encodings")
struct ValueEncodingTests {

    static let values: [Value] = [
        .null,
        .integer(0), .integer(-1), .integer(.max), .integer(.min),
        .double(1.5), .double(-0.0), .double(.infinity), .double(-.infinity), .double(0.1),
        .string(""), .string("Hello 🌍"), .string("a\0b"),
        .data(Data()), .data(Data([0, 1, 2, 255])),
        .path([]), .path(["a", "b/c", "d\\"]),
        .list([]), .list([.integer(-3), .string("x"), .null, .list([.double(2)]), .data(Data([1]))]),
        .map([:]), .map(["a": .path(["x"]), "b": .data(Data([1])), "c": .map(["d": .integer(300)])]),
    ]

    @Test("Tagged round trip", arguments: values, TestedValueEncoding.allCases)
    func tagged(value: Value, encoding: TestedValueEncoding) throws {
        let encoding = encoding.encoding
        let decoded = try encoding.decode(encoding.encode(value))
        #expect(decoded == value)
        #expect(decoded.type == value.type)
    }

    @Test("Content round trip", arguments: values, TestedValueEncoding.allCases)
    func content(value: Value, encoding: TestedValueEncoding) throws {
        let encoding = encoding.encoding
        let decoded = try encoding.decodeContent(encoding.encodeContent(of: value), as: value.type)
        #expect(decoded == value)
        #expect(decoded.type == value.type)
    }

    @Test("NaN round trip", arguments: TestedValueEncoding.allCases)
    func nan(encoding: TestedValueEncoding) throws {
        let encoding = encoding.encoding
        #expect(try encoding.decode(encoding.encode(.double(.nan))).doubleValue?.isNaN == true)
        #expect(try encoding.decodeContent(encoding.encodeContent(of: .double(.nan)), as: .double).doubleValue?.isNaN == true)
        let list = try encoding.decode(encoding.encode(.list([.double(.nan)])))
        #expect(list.listValue?.first?.doubleValue?.isNaN == true)
    }

    @Test("Binary format")
    func binary() throws {
        let encoding = BinaryValueEncoding()
        // Content only
        #expect(try encoding.encodeContent(of: .null) == Data())
        #expect(try encoding.encodeContent(of: .integer(-1)) == Data([1]))
        #expect(try encoding.encodeContent(of: .integer(300)) == Data([0xD8, 0x04]))
        #expect(try encoding.encodeContent(of: .string("x")) == Data([1, 0x78]))
        #expect(try encoding.encodeContent(of: .path(["a", "bc"])) == Data([2, 1, 0x61, 2, 0x62, 0x63]))
        #expect(try encoding.encodeContent(of: .list([.integer(-1), .string("x"), .path([]), .null])) == Data([4, 1, 1, 3, 1, 0x78, 5, 0, 0]))
        #expect(try encoding.encodeContent(of: .map(["b": .integer(300), "a": .double(1)])) == Data([2, 1, 0x61, 2, 0, 0, 0, 0, 0, 0, 0xF0, 0x3F, 1, 0x62, 1, 0xD8, 0x04]))
        // Tagged values are the type code followed by the content
        #expect(try encoding.encode(.null) == Data([0]))
        #expect(try encoding.encode(.integer(-1)) == Data([1, 1]))
        #expect(try encoding.encode(.path(["a", "bc"])) == Data([5, 2, 1, 0x61, 2, 0x62, 0x63]))
    }

    @Test("Binary decoding errors", arguments: [
        (Data(), nil),                    // Missing type
        (Data([8]), nil),                 // Unknown type
        (Data([1, 1, 0]), nil),           // Trailing bytes
        (Data([3, 5, 0x61]), nil),        // String too short
        (Data([6, 2, 1, 1]), nil),        // List too short
        (Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]), .integer),  // Varint too long
        (Data([0, 0, 0]), .double),       // Double too short
        (Data([0]), .null),               // Content for null
    ] as [(Data, ValueType?)])
    func binaryErrors(data: Data, type: ValueType?) {
        let encoding = BinaryValueEncoding()
        #expect(throws: DecodingError.self) {
            if let type {
                _ = try encoding.decodeContent(data, as: type)
            } else {
                _ = try encoding.decode(data)
            }
        }
    }

    @Test("JSON format")
    func json() throws {
        let encoding = JSONValueEncoding()
        func string(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }
        #expect(string(try encoding.encode(.integer(5))) == #"["integer",5]"#)
        #expect(string(try encoding.encode(.null)) == #"["null",null]"#)
        #expect(string(try encoding.encodeContent(of: .integer(5))) == "5")
        #expect(string(try encoding.encodeContent(of: .double(2))) == "2")
        #expect(string(try encoding.encodeContent(of: .null)) == "null")
        #expect(string(try encoding.encodeContent(of: .path(["a", "b/c"]))) == #"["a","b/c"]"#)
        #expect(string(try encoding.encodeContent(of: .list([.integer(1), .string("x")]))) == #"["integer",1,"string","x"]"#)
        #expect(string(try encoding.encodeContent(of: .map(["k": .double(.nan), "a": .null]))) == #"["a","null",null,"k","double","nan"]"#)
    }

    @Test("Compact JSON format")
    func compactJSON() throws {
        let encoding = CompactJSONValueEncoding()
        func string(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }
        #expect(string(try encoding.encode(.integer(5))) == "[1,5]")
        #expect(string(try encoding.encode(.null)) == "[0,null]")
        #expect(string(try encoding.encodeContent(of: .list([.integer(1), .string("x")]))) == #"[1,1,3,"x"]"#)
        #expect(string(try encoding.encodeContent(of: .map(["b": .data(Data([1])), "a": .path(["x"])]))) == #"["a",5,["x"],"b",4,"AQ=="]"#)
    }

    @Test("Values match the message encoding")
    func matchesMessageEncoding() throws {
        let value = Value.map(["a": .list([.integer(1), .double(.infinity)]), "b": .data(Data([1]))])
        let message = String(decoding: try JsonEncoding().encode(.value(value, for: [])), as: UTF8.self)
        let content = String(decoding: try JSONValueEncoding().encodeContent(of: value), as: UTF8.self)
        #expect(message.contains(#""value":\#(content)"#))
    }

    @Test("JSON decoding errors", arguments: [
        ("", nil),                        // Empty data
        ("[]", nil),                      // Missing type
        (#"["unknown",1]"#, nil),         // Unknown type
        (#"["integer"]"#, nil),           // Missing content
        (#"["integer",1,2]"#, nil),       // Trailing element
        (#"["integer",1] 2"#, nil),       // Trailing data
        ("1 2", .integer),                // Trailing content
        (#""x""#, .list),                 // Wrong content type
    ] as [(String, ValueType?)])
    func jsonErrors(json: String, type: ValueType?) {
        let encoding = JSONValueEncoding()
        let data = Data(json.utf8)
        #expect(throws: (any Error).self) {
            if let type {
                _ = try encoding.decodeContent(data, as: type)
            } else {
                _ = try encoding.decode(data)
            }
        }
    }

    @Test("Content must match the type", arguments: TestedValueEncoding.allCases)
    func typeMismatch(encoding: TestedValueEncoding) throws {
        let encoding = encoding.encoding
        let data = try encoding.encodeContent(of: .string("text"))
        #expect(throws: (any Error).self) {
            _ = try encoding.decodeContent(data, as: .list)
        }
    }
}
