/**
 A type that can be converted to and from a SOIL ``SampleTree``.

 While ``ValueConvertible`` types are stored as a single value at one path,
 conforming types can spread their data over multiple nodes of a tree,
 so that other SOIL components can access (and subscribe to) individual parts.

 Default implementations are provided for some types, which only need to declare the conformance:

 | Swift type | SOIL tree |
 | --- | --- |
 | ``ValueConvertible`` | The value as a sample at the root node |
 | `Codable` | Keyed containers become child nodes, all other values are samples at their node |

 ```swift
 struct Robot: Codable, SampleTreeConvertible {
     var name: String          // Stored at ["name"]
     var position: Position    // Stored at ["position", "x"] and ["position", "y"]
     var waypoints: [Position] // Stored as a list value at ["waypoints"]
 }
 ```

 For `Codable` types that also conform to ``ValueConvertible``, the `Codable` tree structure is used.

 When converting a tree to a type, the current sample (see ``SampleTree/currentSample``) of each node is used.

 Converting to a SOIL tree throws if the value can't be represented,
 e.g. for unsigned integers larger than `Int.max`.
 Conforming types that can always be converted may implement ``sampleTree`` without `throws`.
 */
public protocol SampleTreeConvertible: Sendable {

    /**
     Create a value from a SOIL tree.
     - Parameter sampleTree: The SOIL tree to convert
     - Returns: `nil`, if the tree can't be converted
     */
    init?(sampleTree: any SampleTree)

    /**
     The value converted to a SOIL tree.
     - Throws: An error, if the value can't be represented as a SOIL tree
     */
    var sampleTree: any SampleTree { get throws }
}

// MARK: Default implementations

extension SampleTreeConvertible where Self: ValueConvertible {

    public init?(sampleTree: any SampleTree) {
        guard let value = sampleTree.currentValue(as: Self.self) else {
            return nil
        }
        self = value
    }

    public var sampleTree: any SampleTree {
        get throws { ImmutableSampleTree(value: try soilValue) }
    }
}

extension SampleTreeConvertible where Self: Codable {

    public init?(sampleTree: any SampleTree) {
        guard let value = try? ValueDecoder().decode(Self.self, from: sampleTree.mergedValue) else {
            return nil
        }
        self = value
    }

    public var sampleTree: any SampleTree {
        get throws { try ValueEncoder().encode(self).expandedTree }
    }
}

extension SampleTreeConvertible where Self: ValueConvertible & Codable {

    // Prefer the tree structure, otherwise the type could just be stored as a value

    public init?(sampleTree: any SampleTree) {
        guard let value = try? ValueDecoder().decode(Self.self, from: sampleTree.mergedValue) else {
            return nil
        }
        self = value
    }

    public var sampleTree: any SampleTree {
        get throws { try ValueEncoder().encode(self).expandedTree }
    }
}

// MARK: Conversion between values and trees

extension Value {

    /// The value as a tree, where maps are expanded into child nodes
    fileprivate var expandedTree: any SampleTree {
        guard case .map(let values) = self else {
            return ImmutableSampleTree(value: self)
        }
        return ImmutableSampleTree(children: values.mapValues { $0.expandedTree })
    }
}

extension SampleTree {

    /**
     The tree collapsed into a single value.

     Nodes with samples are represented by their current value,
     nodes without samples are represented as a map of their children.
     */
    fileprivate var mergedValue: Value {
        if let currentValue {
            return currentValue
        }
        return .map(children.mapValues { $0.mergedValue })
    }

    /**
     Set a timestamp for all samples in the tree that don't have one.
     - Parameter timestamp: The timestamp to set
     - Returns: The tree with the timestamps set
     */
    func withTimestamp(_ timestamp: Timestamp) -> any SampleTree {
        ImmutableSampleTree(
            samples: samples.map { $0.timestamp == nil ? Sample(value: $0.value, timestamp: timestamp) : $0 },
            children: children.mapValues { $0.withTimestamp(timestamp) })
    }
}
