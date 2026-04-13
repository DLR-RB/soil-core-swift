import Foundation

/**
 * A receiver that prints all received samples to the standard output
 */
public final class PrintReceiver {

    private let pathFormatter: PathFormatter

    private let df: DateFormatter

    private let prefix: String

    /**
     Create a new print receiver
     - Parameter pathFormatter: The formatter to convert paths to strings
     - Parameter dateFormat: The formatter to convert timestamps to strings
     - Parameter prefix: A prefix to print before each sample
     */
    public init(pathFormatter: PathFormatter = SeparatedPathFormatter(), dateFormat: DateFormatter = PrintReceiver.defaultDateFormatter, prefix: String? = nil) {
        self.pathFormatter = pathFormatter
        self.df = dateFormat
        self.prefix = prefix ?? ""
    }

    /**
     The date formatter used by default.

     Both date and time are printed `short`
     */
    public static var defaultDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }
}

extension PrintReceiver: Receiver {

    /**
     Receive a request to print a tree for a path.
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     - Returns: A request handle, to optionally wait until the data is printed.
     */
    public func receive(_ tree: any SampleTree, for path: Path) -> any Request {
        print(tree, for: path)
        return CompletedRequest()
    }

    private func timeString(for sample: Sample) -> String {
        guard let timestamp = sample.timestamp else {
            return "now"
        }
        return df.string(from: timestamp)
    }

    /**
     Print all samples of a tree, formatted using the path and date formatter
     */
    private func print(_ tree: any SampleTree, for path: Path) {
        let pathString = pathFormatter.string(from: path)
        for sample in tree.samples {
            Swift.print("\(prefix)\(pathString): \(sample.value) (\(timeString(for: sample)))")
        }
        for (name, child) in tree.children {
            print(child, for: path + [name])
        }
    }
}