import Foundation

/**
 A simple implementation of `Logger` that uses non-persistent log levels,
 and only requires a receiver.

 This class is not an actor, because it's not possible to implement `log(_,format:arguments:)`
 with actor isolation. It needs to access the internal level (in isolation),
 but `any CVarArg` is not sendable.
 We could compute the format string before checking the level, but that would be inefficient.
 Instead, we use a lock to access the property safely.
 */
public final class SimpleLogger: Logger {

    /**
     The default level for logging when no explicit level is set.
     */
    public static let defaultLevel: LogLevel = .warning

    /// The path with which the log messages are published.
    private let path: Path

    /// The receiver to which the log messages are forwarded to
    private let receiver: any Receiver

    /**
     The stored log level for this logger

     We need to declare this property unsafe, because
     we can't make this class an actor to make it concurrency-safe.
     We could use a lock to access the property
     */
    private nonisolated(unsafe) var _level: LogLevel

    /// The lock to safely access the stored log level
    private let lock = NSLock()

    /// Access the stored level via locking for concurrency-safety
    private var level: LogLevel {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _level
        }
        set {
            lock.lock()
            _level = newValue
            lock.unlock()
        }
    }

    /**
     Create a new logger.
     - Parameter path: The path to use for the log messages
     - Parameter receiver: The receiver that handles the log messages
     - Parameter level: The log level to use for filtering messages
     */
    public init(path: Path, receiver: Receiver, level: LogLevel? = nil) {
        self.path = path
        self.receiver = receiver
        self._level = level ?? SimpleLogger.defaultLevel
    }

    /**
     Set the filtering level for this logger
     - Parameter level: The new level (`nil` will set the default level)
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func setLevel(_ level: LogLevel?) -> any Request {
        self.level = level ?? SimpleLogger.defaultLevel
        return CompletedRequest()
    }

    /**
     Get the current log level of this logger
     */
    public func logLevel() async -> LogLevel {
        return level
    }

    /**
     Log a message at the given level.

     Messages below the logger's level are ignored
     - Parameter level: The level of the message
     - Parameter message: The message to log
     - Returns: A request to wait until the operation is completed
     */
    @discardableResult
    public func log(_ level: LogLevel, _ message: String) -> any Request {
        guard level >= self.level else {
            return CompletedRequest()
        }
        return write(level, message)
    }

    /**
     Log a formatted string at the given level.

     Messages below the logger's level are ignored.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter level: The log level of the message
     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    public func log(_ level: LogLevel, format: String, arguments: [any CVarArg]) -> any Request {
        guard level >= self.level else {
            return CompletedRequest()
        }
        let message = String(format: format, arguments: arguments)
        return AsyncRequest {
            await self.write(level, message).wait()
        }
    }

    // MARK: Child loggers

    /**
     Creates a child logger under this logger.
     The child inherits the parent's log level threshold.

     - Parameter component: The subcomponent name
     - Returns: A new ``Logger`` instance representing the child
     */
    public func child(_ component: String) -> any Logger {
        return SimpleLogger(path: path + [component], receiver: receiver, level: level)
    }

    /**
     Creates a child logger under this logger.
     The child inherits the parent's log level threshold.

     - Parameter component: The subcomponent name
     - Parameter level: The log level to set for the child
     - Returns: A new ``Logger`` instance representing the child
     */
    public func child(_ component: String, level: LogLevel) -> any Logger {
        return SimpleLogger(path: path + [component], receiver: receiver, level: level)
    }

    // MARK: Helper

    private func write(_ level: LogLevel, _ message: String) -> any Request {
        receiver.accept(.string(message), for: path + [level.description], at: .current())
    }
}
