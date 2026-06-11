

/**
 A fake logger that simply ignores all messages.

 This logger class can be used when a logger is required, but no actual logging should be performed.
 It is also used occassionally internally within the library.

 The log level can be set and retrieved on each instance, but the value has no effect.
 */
public actor NoLogger: Logger {

    /// The internal level, just to allow setting and getting the level.
    private var level: LogLevel = .warning

    /**
     Set the filtering level for this logger.

     If `nil` is provided as the level, then the logger may use the default level,
     or use the level of a parent node.
     - Parameter level: The log level to use
     - Returns: A request to wait for the application of the level
     */
    public nonisolated func setLevel(_ level: LogLevel?) -> any Request {
        // Nothing to do, all messages ignored anyway
        AsyncRequest {
            await self.setLevelInternal(level)
        }
    }

    private func setLevelInternal(_ level: LogLevel?) {
        self.level = level ?? .warning
    }

    /**
     Get the current log level of this logger
     */
    public func logLevel() async -> LogLevel {
        return level
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
    public nonisolated func log(_ level: LogLevel, _ message: String) -> any Request {
        // All logs are simply ignored
        CompletedRequest()
    }

    /**
     Creates a child logger under this logger.

     - Parameter component: The subcomponent name
     - Returns: A new ``NoLogger`` instance representing the child
     */
    public nonisolated func child(_ component: String) -> any Logger {
        NoLogger()
    }
}