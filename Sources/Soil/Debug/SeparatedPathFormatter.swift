

public final class SeparatedPathFormatter: Sendable {

    private let separator: String

    public init(separator: String = ".") {
        self.separator = separator
    }
}

extension SeparatedPathFormatter: PathFormatter {

    public func string(from path: Path) -> String {
        path.joined(separator: separator)
    }
}