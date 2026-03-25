
/**
 Standard log levels for logging with priorities for filtering.
 */
public enum LogLevel: Int, Hashable,Sendable {

    case trace = 0

    case debug = 1

    case info = 2

    case warning = 3

    case error = 4
}

extension LogLevel: CustomStringConvertible {

    public static func from(_ string: String) -> LogLevel? {
        switch string {
            case "trace": .trace
            case "debug": .debug
            case "info": .info
            case "warning": .warning
            case "error": .error
            default: nil
        }
    }

    public var description: String {
        switch self {
            case .trace: "trace"
            case .debug: "debug"
            case .info: "info"
            case .warning: "warning"
            case .error: "error"
        }
    }
}

extension LogLevel: Comparable {

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}