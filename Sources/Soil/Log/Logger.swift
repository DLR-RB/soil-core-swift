

/**
 A type that receives log messages with different priority levels.
 */
public protocol Logger: Sendable {

    /**
     Set the filtering level for this logger.

     If `nil` is provided as the level, then the logger may use the default level,
     or use the level of a parent node.
     - Parameter level: The log level to use
     - Returns: A request to wait for the application of the level
     */
    @discardableResult
    func setLevel(_ level: LogLevel?) -> any Request

    /**
     Get the current log level of this logger
     */
    func logLevel() async -> LogLevel

    // MARK: Generic logging

    /**
     Log a message at the given level.

     Messages below the logger's level are ignored
     - Parameter level: The level of the message
     - Parameter message: The message to log
     - Returns: A request to wait until the operation is completed
     */
    @discardableResult
    func log(_ level: LogLevel, _ message: String) -> any Request

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
    func log(_ level: LogLevel, format: String, _ arguments: any CVarArg...) -> any Request

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
    func log(_ level: LogLevel, format: String, arguments: [any CVarArg]) -> any Request

    // MARK: Level-specific functions

    /**
     Log a trace message.

     The message is ignored if the log level is higher than `trace`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    func trace(_ message: String) -> any Request

    /**
     Log a debug message.

     The message is ignored if the log level is higher than `debug`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    func debug(_ message: String) -> any Request

    /**
     Log an info message.

     The message is ignored if the log level is higher than `info`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    func info(_ message: String) -> any Request

    /**
     Log a warning message.

     The message is ignored if the log level is higher than `warning`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    func warning(_ message: String) -> any Request

    /**
     Log an error message.

     The message is ignored if the log level is higher than `error`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    func error(_ message: String) -> any Request

    // MARK: Format string functions

    /**
     Log a formatted trace message.

     The message is ignored if the log level is higher than `trace`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    func trace(_ format: String, _ arguments: any CVarArg...) -> any Request

    /**
     Log a formatted debug message.

     The message is ignored if the log level is higher than `debug`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    func debug(_ format: String, _ arguments: any CVarArg...) -> any Request

    /**
     Log a formatted info message.

     The message is ignored if the log level is higher than `info`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    func info(_ format: String, _ arguments: any CVarArg...) -> any Request

    /**
     Log a formatted warning message.

     The message is ignored if the log level is higher than `warning`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    func warning(_ format: String, _ arguments: any CVarArg...) -> any Request

    /**
     Log a formatted error message.

     The message is ignored if the log level is higher than `error`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    func error(_ format: String, _ arguments: any CVarArg...) -> any Request

    // MARK: Child loggers

    /**
     Creates a child logger under this logger.
     The child may inherit the parent's log level threshold.

     - Parameter component: The subcomponent name
     - Returns: A new ``Logger`` instance representing the child
     */
    func child(_ component: String) -> any Logger;

    /**
     Creates a child logger under this logger.
     The child may inherit the parent's log level threshold.

     - Parameter component: The subcomponent name
     - Parameter level: The log level to set for the child
     - Returns: A new ``Logger`` instance representing the child
     */
    func child(_ component: String, level: LogLevel) -> any Logger
}

// MARK: Default implementations

extension Logger {

    /**
     Log a formatted string at the given level.
     Messages below the logger's level are ignored.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter level: The log level of the message
     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    public func log(_ level: LogLevel, format: String, _ arguments: any CVarArg...) -> any Request {
        log(level, format: format, arguments: arguments)
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
        let message = String(format: format, arguments: arguments)
        return log(level, message)
    }

    /**
     Log a trace message.

     The message is ignored if the log level is higher than `trace`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func trace(_ message: String) -> any Request {
        return log(.trace, message);
    }

    /**
     Log a debug message.

     The message is ignored if the log level is higher than `debug`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func debug(_ message: String) -> any Request {
        return log(.debug, message);
    }

    /**
     Log an info message.

     The message is ignored if the log level is higher than `info`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func info(_ message: String) -> any Request {
        return log(.info, message);
    }

    /**
     Log a warning message.

     The message is ignored if the log level is higher than `warning`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func warning(_ message: String) -> any Request {
        return log(.warning, message);
    }

    /**
     Log an error message.

     The message is ignored if the log level is higher than `error`.
     - Parameter message: The message to log
     - Returns: A request to wait for completion
     */
    @discardableResult
    public func error(_ message: String) -> any Request {
        return log(.error, message);
    }

    // MARK: Default format functions

    /**
     Log a formatted trace message.

     The message is ignored if the log level is higher than `trace`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    public func trace(_ format: String, _ arguments: any CVarArg...) -> any Request {
        log(.trace, format: format, arguments: arguments)
    }

    /**
     Log a formatted debug message.

     The message is ignored if the log level is higher than `debug`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    public func debug(_ format: String, _ arguments: any CVarArg...) -> any Request {
        log(.debug, format: format, arguments: arguments)
    }

    /**
     Log a formatted info message.

     The message is ignored if the log level is higher than `info`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    public func info(_ format: String, _ arguments: any CVarArg...) -> any Request {
        log(.info, format: format, arguments: arguments)
    }

    /**
     Log a formatted warning message.

     The message is ignored if the log level is higher than `warning`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    public func warning(_ format: String, _ arguments: any CVarArg...) -> any Request {
        log(.warning, format: format, arguments: arguments)
    }

    /**
     Log a formatted error message.

     The message is ignored if the log level is higher than `error`.
     Logs a string initialized by using the given format string as a template
     into which the remaining argument values are substituted according to the user's default locale.

     - Parameter format: The log message
     - Parameter arguments: The arguments for the format string
     */
    @discardableResult
    public func error(_ format: String, _ arguments: any CVarArg...) -> any Request {
        log(.error, format: format, arguments: arguments)
    }

    // MARK: Child defaults

    /**
     Creates a child logger under this logger.
     The child may inherit the parent's log level threshold.

     - Parameter component: The subcomponent name
     - Parameter level: The log level to set for the child
     - Returns: A new `Logger`` instance representing the child
     */
    public func child(_ component: String, level: LogLevel) -> any Logger {
        let c = child(component)
        c.setLevel(level)
        return c
    }
}