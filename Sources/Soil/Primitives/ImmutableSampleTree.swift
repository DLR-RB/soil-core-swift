
/**
 A path tree containing samples
 */
public struct ImmutableSampleTree: SampleTree, Sendable {

    /// The samples at this tree node
    public let samples: [Sample]

    /// The child nodes of the tree, indexed by their path component.
    public let children: [PathComponent : any SampleTree]

    /**
     Create a tree with samples and children.
     - Parameter samples: The data at the root node
     - Parameter children: The child nodes of the tree root.
     */
    public init(samples: [Sample] = [], children: [PathComponent : any SampleTree] = [:]) {
        self.samples = samples
        self.children = children
    }
}
