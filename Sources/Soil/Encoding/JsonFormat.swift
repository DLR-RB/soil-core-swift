import Foundation

/**
 The fields used in JSON messages.

 The raw values are the keys used in the standard JSON format.
 */
enum JsonField: String, CaseIterable {
    case message
    case path
    case value
    case type
    case samples
    case count
    case depth
    case time
    case end
    case id
    case children
}

/**
 A type used to represent message and value types in JSON.
 */
protocol JsonTag: CustomStringConvertible {

    func write(to writer: inout JsonWriter)

    static func read(from reader: inout JsonReader) throws -> Self
}

extension Int: JsonTag {

    func write(to writer: inout JsonWriter) {
        writer.write(self)
    }

    static func read(from reader: inout JsonReader) throws -> Int {
        try reader.readInt()
    }
}

extension String: JsonTag {

    func write(to writer: inout JsonWriter) {
        writer.write(self)
    }

    static func read(from reader: inout JsonReader) throws -> String {
        try reader.readString()
    }
}

/**
 Describes the properties in which the different JSON encodings differ.

 The actual encoding and decoding logic is shared in ``JsonCoding``.
 */
protocol JsonFormat {

    /// The representation of message and value types
    associatedtype Tag: JsonTag

    /// The key used for a field
    static func key(for field: JsonField) -> String

    /// The field identified by a key, if the key is known
    static func field(for key: String) -> JsonField?

    static func tag(for type: MessageType) -> Tag

    static func messageType(from tag: Tag) -> MessageType?

    static func tag(for type: ValueType) -> Tag

    static func valueType(from tag: Tag) -> ValueType?
}

extension JsonFormat {

    static func field(for key: String) -> JsonField? {
        JsonField.allCases.first { self.key(for: $0) == key }
    }
}

/**
 The shared implementation of the JSON message encodings, parameterized by the concrete format.
 */
enum JsonCoding<Format: JsonFormat> {

    static func encode(_ message: Message) throws -> Data {
        var writer = JsonWriter()
        try write(message, to: &writer)
        return writer.data
    }

    static func decode(_ data: Data) throws -> Message {
        try data.withUnsafeBytes { bytes in
            var reader = JsonReader(bytes: bytes)
            let message = try readMessage(from: &reader)
            try reader.expectEnd()
            return message
        }
    }
}

// MARK: Encoding

extension JsonCoding {

    private static func writeKey(_ field: JsonField, to writer: inout JsonWriter, first: inout Bool) {
        writer.writeKey(Format.key(for: field), first: &first)
    }

    private static func write(_ message: Message, to writer: inout JsonWriter) throws {
        // Encode the message in a single top-level object
        writer.beginObject()
        var first = true
        // Only encode message type if not a data message
        if message.type != .data {
            writeKey(.message, to: &writer, first: &first)
            Format.tag(for: message.type).write(to: &writer)
        }
        // If the path is absent, then it defaults to an empty path
        if !message.path.isEmpty {
            writeKey(.path, to: &writer, first: &first)
            write(message.path, to: &writer)
        }
        // Encode data to the top-level object

        // There is a possibly invalid message where the `time` is set in addition to data being present
        // We ensure that the timestamp is not written into the message if any samples are provided
        // so that decoding does not fail
        try write(message.data, to: &writer, first: &first, canUseRootContainer: message.time == nil)

        if let count = message.count {
            writeKey(.count, to: &writer, first: &first)
            writer.write(count)
        }
        if let depth = message.depth {
            writeKey(.depth, to: &writer, first: &first)
            writer.write(depth)
        }
        if let time = message.time {
            writeKey(.time, to: &writer, first: &first)
            try writer.write(time.timeIntervalSince1970)
        }
        if let end = message.end {
            writeKey(.end, to: &writer, first: &first)
            try writer.write(end.timeIntervalSince1970)
        }
        if let id = message.id {
            writeKey(.id, to: &writer, first: &first)
            writer.write(id)
        }
        writer.endObject()
    }

    /// Write a path as an array of strings
    private static func write(_ path: Path, to writer: inout JsonWriter) {
        writer.beginArray()
        for (index, component) in path.enumerated() {
            if index > 0 { writer.writeComma() }
            writer.write(component)
        }
        writer.endArray()
    }

    /**
     Write the fields of a sample tree into the current object.
     - Parameter canUseRootContainer: Indicates if a single sample can be encoded directly in the current object
     */
    private static func write(_ tree: any SampleTree, to writer: inout JsonWriter, first: inout Bool, canUseRootContainer: Bool = true) throws {
        let samples = tree.samples
        switch samples.count {
            case 0: break
            case 1:
                guard canUseRootContainer else {
                    // Encode the single sample within the `samples` field,
                    // because the `time` field is already used
                    fallthrough
                }
                try write(samples[0], to: &writer, first: &first)
            default:
                writeKey(.samples, to: &writer, first: &first)
                writer.beginArray()
                for (index, sample) in samples.enumerated() {
                    if index > 0 { writer.writeComma() }
                    writer.beginObject()
                    var sampleFirst = true
                    try write(sample, to: &writer, first: &sampleFirst)
                    writer.endObject()
                }
                writer.endArray()
        }

        let children = tree.children
        guard !children.isEmpty else {
            return
        }

        writeKey(.children, to: &writer, first: &first)
        writer.beginObject()
        var childrenFirst = true
        for (name, child) in children {
            writer.writeKey(name, first: &childrenFirst)
            writer.beginObject()
            var childFirst = true
            try write(child, to: &writer, first: &childFirst)
            writer.endObject()
        }
        writer.endObject()
    }

    /// Write the value and timestamp of a sample into the current object
    private static func write(_ sample: Sample, to writer: inout JsonWriter, first: inout Bool) throws {
        try write(sample.value, to: &writer, first: &first)
        if let timestamp = sample.timestamp {
            writeKey(.time, to: &writer, first: &first)
            try writer.write(timestamp.timeIntervalSince1970)
        }
    }

    /**
     Write a value into the current object.

     The value is encoded either as a number, nil, a string, or a list.
     If the string represents data or a non-finite double, the number represents an integer,
     or the list represents a map, then the value type is added to disambiguate.
    */
    private static func write(_ value: Value, to writer: inout JsonWriter, first: inout Bool) throws {
        let type = value.type
        switch value {
        case .data, .integer, .list, .map:
                writeKey(.type, to: &writer, first: &first)
                Format.tag(for: type).write(to: &writer)
            case .double(let double) where !double.isFinite:
                writeKey(.type, to: &writer, first: &first)
                Format.tag(for: type).write(to: &writer)
            default: break
        }
        writeKey(.value, to: &writer, first: &first)
        try writeContent(of: value, to: &writer)
    }

    /**
     Write a double value.

     JSON numbers can't represent NaN and infinity, so these are written as the strings `"nan"`, `"inf"` and `"-inf"`.
     The value must then be preceded by its type, so that it can be distinguished from a string.
     All NaN values (signaling, negative, or with payload) are written as `"nan"`.
     */
    private static func write(_ value: Double, to writer: inout JsonWriter) throws {
        if value.isNaN {
            writer.write("nan")
        } else if value.isInfinite {
            writer.write(value < 0 ? "-inf" : "inf")
        } else {
            try writer.write(value)
        }
    }

    /// Write a value preceded by its type, as used in lists and maps
    private static func writeTagged(_ value: Value, to writer: inout JsonWriter) throws {
        Format.tag(for: value.type).write(to: &writer)
        writer.writeComma()
        try writeContent(of: value, to: &writer)
    }

    private static func writeContent(of value: Value, to writer: inout JsonWriter) throws {
        switch value {
            case .null: writer.writeNull()
            case .integer(let value): writer.write(value)
            case .double(let value): try write(value, to: &writer)
            case .string(let value): writer.write(value)
            case .path(let value): write(value, to: &writer)
            case .data(let value): writer.write(value)
            case .list(let values):
                writer.beginArray()
                for (index, element) in values.enumerated() {
                    if index > 0 { writer.writeComma() }
                    try writeTagged(element, to: &writer)
                }
                writer.endArray()
            case .map(let values):
                writer.beginArray()
                var first = true
                for (key, element) in values {
                    if first { first = false } else { writer.writeComma() }
                    writer.write(key)
                    writer.writeComma()
                    try writeTagged(element, to: &writer)
                }
                writer.endArray()
        }
    }
}

// MARK: Decoding

extension JsonCoding {

    /**
     The fields of a JSON object.

     Messages, tree nodes and samples all use the same fields,
     and unused fields are ignored.
     */
    private struct Fields {
        var message: Format.Tag?
        var path: Path?
        var value: Value?
        /// The offset of the value, in case it needs to be read again after the type is known
        var valueOffset: Int?
        /// Indicate that the value was read (or skipped) before the type was known
        var valueIsUntyped = false
        var type: Format.Tag?
        var samples: [Sample] = []
        var children: [PathComponent : any SampleTree] = [:]
        var count: Int?
        var depth: Int?
        var time: Double?
        var end: Double?
        var id: Int?

        var hasValue: Bool {
            valueOffset != nil
        }
    }

    private static func readMessage(from reader: inout JsonReader) throws -> Message {
        let fields = try readFields(from: &reader)
        let type: MessageType
        if let rawType = fields.message {
            guard let t = Format.messageType(from: rawType) else {
                throw reader.error("Unknown message type: \(rawType)")
            }
            type = t
        } else {
            type = .data
        }
        return Message(
            type: type,
            path: fields.path ?? [],
            // If a value is present, then the timestamp is decoded as part of the sample
            time: fields.hasValue ? nil : fields.time.map(Timestamp.init(timeIntervalSince1970:)),
            data: tree(from: fields),
            count: fields.count,
            depth: fields.depth,
            end: fields.end.map(Timestamp.init(timeIntervalSince1970:)),
            id: fields.id)
    }

    private static func tree(from fields: Fields) -> ImmutableSampleTree {
        guard let value = fields.value else {
            return ImmutableSampleTree(samples: fields.samples.sorted(), children: fields.children)
        }
        let sample = Sample(value: value, timestamp: fields.time.map(Timestamp.init(timeIntervalSince1970:)))
        return ImmutableSampleTree(samples: (fields.samples + [sample]).sorted(), children: fields.children)
    }

    private static func readFields(from reader: inout JsonReader) throws -> Fields {
        var fields = Fields()
        try reader.beginObject()
        var first = true
        while let key = try reader.nextKey(first: &first) {
            guard let field = Format.field(for: key) else {
                try reader.skipValue()
                continue
            }
            switch field {
                case .message: fields.message = try Format.Tag.read(from: &reader)
                case .path: fields.path = try readPath(from: &reader)
                case .type: fields.type = try Format.Tag.read(from: &reader)
                case .count: fields.count = try reader.readInt()
                case .depth: fields.depth = try reader.readInt()
                case .id: fields.id = try reader.readInt()
                case .time: fields.time = try reader.readDouble()
                case .end: fields.end = try reader.readDouble()
                case .samples: fields.samples = try readSamples(from: &reader)
                case .children: fields.children = try readChildren(from: &reader)
                case .value:
                    fields.valueOffset = reader.offset
                    fields.valueIsUntyped = fields.type == nil
                    if fields.valueIsUntyped, try reader.peekKind() == .array {
                        // Could be a path, a list or a map, depending on a type that may follow
                        fields.value = nil
                        try reader.skipValue()
                    } else {
                        fields.value = try readValue(from: &reader, type: fields.type)
                    }
            }
        }
        try resolveValue(of: &fields, from: &reader)
        return fields
    }

    /**
     Read the value again, if it was read (or skipped) before its type was known.

     The encoder always writes the type before the value, so this only happens for JSON from other sources.
     */
    private static func resolveValue(of fields: inout Fields, from reader: inout JsonReader) throws {
        guard fields.valueIsUntyped, let valueOffset = fields.valueOffset,
              fields.type != nil || fields.value == nil else {
            return
        }
        let endOffset = reader.offset
        reader.offset = valueOffset
        fields.value = try readValue(from: &reader, type: fields.type)
        reader.offset = endOffset
    }

    private static func readPath(from reader: inout JsonReader) throws -> Path {
        var path: Path = []
        try reader.beginArray()
        var first = true
        while try reader.nextElement(first: &first) {
            path.append(try reader.readString())
        }
        return path
    }

    private static func readSamples(from reader: inout JsonReader) throws -> [Sample] {
        var samples: [Sample] = []
        try reader.beginArray()
        var first = true
        while try reader.nextElement(first: &first) {
            let fields = try readFields(from: &reader)
            guard let value = fields.value else {
                throw reader.error("Missing value in sample")
            }
            guard let time = fields.time else {
                throw reader.error("Missing time in sample")
            }
            samples.append(Sample(value: value, timestamp: .init(timeIntervalSince1970: time)))
        }
        return samples
    }

    private static func readChildren(from reader: inout JsonReader) throws -> [PathComponent : any SampleTree] {
        var children: [PathComponent : any SampleTree] = [:]
        try reader.beginObject()
        var first = true
        while let name = try reader.nextKey(first: &first) {
            children[name] = tree(from: try readFields(from: &reader))
        }
        return children
    }

    private static func valueType(from tag: Format.Tag, reader: JsonReader) throws -> ValueType {
        guard let type = Format.valueType(from: tag) else {
            throw reader.error("Unknown value type: \(tag)")
        }
        return type
    }

    /**
     Read a value.

     Doubles outside of the representable range are converted to infinity,
     and integers outside of the range of `Int` are clamped to `Int.min` or `Int.max`.
     - Parameter type: The type of the value, if specified. Otherwise the type is inferred from the JSON.
     */
    private static func readValue(from reader: inout JsonReader, type: Format.Tag?) throws -> Value {
        guard let type else {
            // No type information, so detect it
            switch try reader.peekKind() {
                case .null:
                    try reader.readNull()
                    return .null
                case .number: return .double(try reader.readDouble(allowingOverflow: true))
                case .string: return .string(try reader.readString())
                // Lists and maps are always written with a type, so an untyped array is a path
                case .array: return .path(try readPath(from: &reader))
                case .bool, .object: throw reader.error("Invalid value")
            }
        }
        switch try valueType(from: type, reader: reader) {
            case .null:
                try reader.skipValue()
                return .null
            case .data: return .data(try reader.readData())
            case .integer: return .integer(try reader.readInt(clamping: true))
            case .double: return .double(try readDouble(from: &reader))
            case .string: return .string(try reader.readString())
            case .path: return .path(try readPath(from: &reader))
            case .list: return .list(try readList(from: &reader))
            case .map: return .map(try readMap(from: &reader))
        }
    }

    /**
     Read a double value, which is either a number, or a string for NaN and infinity.

     Numbers outside of the range of `Double` are converted to infinity.
     */
    private static func readDouble(from reader: inout JsonReader) throws -> Double {
        guard try reader.peekKind() == .string else {
            return try reader.readDouble(allowingOverflow: true)
        }
        switch try reader.readString() {
            case "nan": return .nan
            case "inf": return .infinity
            case "-inf": return -.infinity
            case let string: throw reader.error("Invalid double '\(string)'")
        }
    }

    /// Read a value preceded by its type, as used in lists and maps
    private static func readTaggedValue(from reader: inout JsonReader, first: inout Bool) throws -> Value {
        let type = try Format.Tag.read(from: &reader)
        guard try reader.nextElement(first: &first) else {
            throw reader.error("Missing value after type")
        }
        return try readValue(from: &reader, type: type)
    }

    private static func readList(from reader: inout JsonReader) throws -> [Value] {
        var values: [Value] = []
        try reader.beginArray()
        var first = true
        while try reader.nextElement(first: &first) {
            values.append(try readTaggedValue(from: &reader, first: &first))
        }
        return values
    }

    private static func readMap(from reader: inout JsonReader) throws -> [String: Value] {
        var values: [String: Value] = [:]
        try reader.beginArray()
        var first = true
        while try reader.nextElement(first: &first) {
            let key = try reader.readString()
            guard try reader.nextElement(first: &first) else {
                throw reader.error("Missing value after map key")
            }
            values[key] = try readTaggedValue(from: &reader, first: &first)
        }
        return values
    }
}
