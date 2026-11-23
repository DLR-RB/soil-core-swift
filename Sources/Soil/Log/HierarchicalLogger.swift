
/**
 A logger implementation that uses the log level of parent nodes
 if no specific log level is set.
 This allows changing the log level for entire logging trees at once.

 - Note: The `log(_:format:arguments:)` function always creates the format string,
   even if the message is discarded due to the log level. This is due to the missing conformance
   if `CVarArg` to Sendable, so that the level can't be checked in an isolated context.
 */
public struct HierarchicalLogger: Logger {

    /**
     The default level for logging when no explicit level is set.
     */
    public static let defaultLevel: LogLevel = .warning

    /// The parent logger from which the log level is inherited
    private let parent: (any Logger)?

    /// The tree node to write log entries
    private let logNode: StorageNode

    /// The tree node to write the log level
    private let levelNode: StorageNode

    public init(parent: (any Logger)? = nil, node: StorageNode) {
        self.parent = parent
        self.logNode = node
        self.levelNode = node.child(named: "level")
    }

    /**
     Create a logger for a storage at a path.
     - Parameter storage: The storage to use as the logging backend
     - Parameter path: The path to use for the logger
     */
    public init(storage: Storage, path: Path = []) {
        self.init(node: StorageNode(storage: storage, path: path))
    }

    /**
     Set the filtering level for this logger.

     If `nil` is provided as the level, then the logger uses
     the first available level of a parent nodes up to the root,
     or the default level.
     - Parameter level: The log level to use
     - Returns: A request to wait for the application of the level
     */
    @discardableResult
    public nonisolated func setLevel(_ level: LogLevel?) -> any Request {
        AsyncRequest {
            if let level {
                await self.levelNode.set(.string(level.description)).wait()
            } else {
                await self.levelNode.setNull().wait()
            }
        }
    }

    /**
     Get the current log level of this logger.

     If no explicit level is set for this logger,
     then the level of the parent is used.
     */
    public func logLevel() async -> LogLevel {
        if let raw = await levelNode.value(as: String.self),
           let level = LogLevel.from(raw) {
            return level
        }
        guard let parent else {
            return HierarchicalLogger.defaultLevel
        }
        return await parent.logLevel()
    }

    // MARK: Generic logging

    /**
     Log a message at the given level.

     Messages below the logger's level are ignored
     - Parameter level: The level of the message
     - Parameter message: The message to log
     - Returns: A request to wait until the operation is completed
     */
    @discardableResult
    public nonisolated func log(_ level: LogLevel, _ message: String) -> any Request {
        AsyncRequest {
            let effectiveLevel = await self.logLevel()
            guard level >= effectiveLevel else {
                return
            }
            self.logNode.accept(.string(message), for: [level.description], at: .current())
        }
    }

    // MARK: Child loggers

    /**
     Creates a child logger under this logger.
     The child may inherit the parent's log level threshold.

     - Parameter component: The subcomponent name
     - Returns: A new ``Logger`` instance representing the child
     */
    public nonisolated func child(_ component: String) -> any Logger {
        HierarchicalLogger(parent: self, node: logNode.child(named: component))
    }
}
