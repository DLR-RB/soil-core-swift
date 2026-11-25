import Foundation

/**
 A utility that can print formatted trees for visualization of data.
 */
public struct TreePrinter {

    public static let dateFormat: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy hh:mm:ss"
        return df
    }()

    let indentation: String

    let dateFormat: DateFormatter

    let separator: String

    public init(
        indentation: String = "  ",
        dateFormat: DateFormatter = TreePrinter.dateFormat,
        separator: String = " > "
    ) {
        self.indentation = indentation
        self.dateFormat = dateFormat
        self.separator = separator
    }

    /**
     Print a tree to standard output.
     - Parameter tree: The tree to visualize
     - Parameter indent: The indent to put in front of each line
     - Parameter path: The path where the tree is located
     */
    public func print(tree: any SampleTree, indent: String = "", path: Path = []) {
        var lines: [String] = []
        parse(tree, indent: indent, path: path, lines: &lines)
        for line in lines {
            Swift.print(line)
        }
    }

    /**
     Create a string representation of a tree
     - Parameter tree: The tree to visualize
     - Parameter indent: The indent to put in front of each line
     - Parameter path: The path where the tree is located
     */
    public func describe(tree: any SampleTree, indent: String = "", path: Path = []) -> String {
        var lines: [String] = []
        parse(tree, indent: indent, path: path, lines: &lines)
        return lines.joined(separator: "\n")
    }

    private func parse(_ tree: any SampleTree, indent: String, path: Path, lines: inout [String]) {
        let samples = tree.samples
        let children = tree.children

        switch children.count {
            case 0:
                // No children, only samples at this node
                switch samples.count {
                    case 0:
                        describe(path: path, indent: indent, text: ": No data", lines: &lines)
                    case 1:
                        describe(sample: samples[0], path: path, prefix: " = ", indent: indent, lines: &lines)
                    default:
                        describe(path: path, indent: indent, text: ": \(samples.count) samples", lines: &lines)
                        for sample in samples {
                            describe(sample: sample, path: [], prefix: "", indent: indent + indentation, lines: &lines)
                        }
                }
            case 1:
                // Single child
                let (name, child) = children.first!
                switch samples.count {
                    case 0:
                        // No samples, so continue the path
                        parse(child, indent: indent, path: path + [name], lines: &lines)
                    case 1:
                        // One sample, one child
                        describe(sample: samples[0], path: path, prefix: " = ", indent: indent, lines: &lines)
                        // Increase indent, but remove the path, it's already printed for the current node
                        parse(child, indent: indent + indentation, path: [name], lines: &lines)
                    default:
                        // Multiple samples, one child
                        describe(path: path, indent: indent, text: ": \(samples.count) samples", lines: &lines)
                        for sample in samples {
                            describe(sample: sample, path: [], prefix: "", indent: indent + indentation, lines: &lines)
                        }
                        // Increase indent, but remove the path, it's already printed for the current node
                        parse(child, indent: indent + indentation, path: [name], lines: &lines)
                }

            default:
                // Multiple children
                switch samples.count {
                    case 0:
                        describe(path: path, indent: indent, text: ":", lines: &lines)
                    case 1:
                        describe(sample: samples[0], path: path, prefix: " = ", indent: indent, lines: &lines)
                    default:
                        describe(path: path, indent: indent, text: ": \(samples.count) samples", lines: &lines)
                        for sample in samples {
                            describe(sample: sample, path: [], prefix: "", indent: indent, lines: &lines)
                        }
                }
                for (name, child) in children.sorted(by: {$0.key < $1.key }) {
                    // Increase indent, but remove the path, it's already printed for the current node
                    parse(child, indent: indent + "  ", path: [name], lines: &lines)
                }
        }
    }

    private func describe(sample: Sample, path: Path, prefix: String, indent: String, lines: inout [String]) {
        if let timestamp = sample.timestamp {
            let date = dateFormat.string(from: timestamp)
            describe(path: path, indent: indent, text: prefix + "\(sample.value) (\(date))", lines: &lines)
        } else {
            describe(path: path, indent: indent, text: prefix + "\(sample.value)", lines: &lines)
        }
    }

    private func describe(path: Path, indent: String, text: String, lines: inout [String]) {
        lines.append(indent + path.joined(separator: separator) + text)
    }
}
