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

    public func receive(_ samples: [Sample], for path: Path) -> any Request {
        let pathString = pathFormatter.string(from: path)
        for sample in samples {
            print("\(prefix)\(pathString): \(sample.value) (\(df.string(from: sample.timestamp)))")
        }
        return CompletedRequest()
    }
}