import Foundation

/**
 * A receiver that prints all received samples to the standard output
 */
public final class PrintReceiver {

    private let pathFormatter: PathFormatter

    private let df: DateFormatter

    /**
     Create a new print receiver
     - Parameter pathFormatter: The formatter to convert paths to strings
     - Parameter dateFormat: The formatter to convert timestamps to strings
     */
    public init(pathFormatter: PathFormatter = SeparatedPathFormatter(), dateFormat: DateFormatter = .init()) {
        self.pathFormatter = pathFormatter
        self.df = dateFormat
    }
}

extension PrintReceiver: Receiver {

    public func receive(_ samples: [Sample], for path: Path) -> any Request {
        let pathString = pathFormatter.string(from: path)
        for sample in samples {
            print("\(pathString): \(sample.value) (\(df.string(from: sample.timestamp)))")
        }
        return CompletedRequest()
    }
}