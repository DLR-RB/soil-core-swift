import Testing
import Foundation
import Soil

@Suite("Tree Printer")
struct TreePrinterTests {

    private func compare(_ tree: any SampleTree, _ description: String) {
        let printer = TreePrinter()
        let result = printer.describe(tree: tree)
        #expect(result == description)
    }

    @Test("Tree with one value")
    func treeWithOneValue() throws {
        let tree = ImmutableSampleTree(
            children: ["a" : ImmutableSampleTree(
                children: [
                    "b": ImmutableSampleTree(
                        children: [
                            "c" : ImmutableSampleTree(value: .integer(123))
                        ]
                    )
                ]
            )]
        )

        let expected =
        """
        a > b > c = 123
        """
        compare(tree, expected)
    }

    @Test("Tree with multiple values")
    func treeWithMultipleValues() throws {
        let tree = ImmutableSampleTree(
            children: ["a" : ImmutableSampleTree(
                children: [
                    "b": ImmutableSampleTree(
                        children: [
                            "c" : ImmutableSampleTree(samples: [
                                .init(value: .integer(123)),
                                .init(value: .double(3.14), timestamp: .init(timeIntervalSince1970: 10000)),
                                .init(value: .string("abc"))
                            ])
                        ]
                    )
                ]
            )]
        )


        let expected =
        """
        a > b > c: 3 samples
          123
          3.14 (01.01.1970 02:46:40)
          'abc'
        """
        compare(tree, expected)
    }
}