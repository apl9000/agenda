import Foundation

/// Log levels for the application logger.
public enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var prefix: String {
        switch self {
        case .debug: return "[DEBUG]"
        case .info: return "[INFO]"
        case .warning: return "[WARN]"
        case .error: return "[ERROR]"
        }
    }
}

/// A thread-safe logger that writes to stderr.
///
/// MCP servers must write all logs to stderr since stdout is reserved
/// for JSON-RPC communication with the client.
public actor Logger {
    /// The shared logger instance.
    public static let shared = Logger()

    /// The minimum log level to output.
    public var minimumLevel: LogLevel = .info

    /// Whether to include timestamps in log output.
    public var includeTimestamp: Bool = true

    /// Whether logging is enabled.
    public var isEnabled: Bool = true

    private let dateFormatter: DateFormatter

    private init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    /// Logs a message at the specified level.
    ///
    /// - Parameters:
    ///   - level: The log level.
    ///   - message: The message to log.
    ///   - file: The source file (auto-populated).
    ///   - function: The function name (auto-populated).
    ///   - line: The line number (auto-populated).
    public func log(
        _ level: LogLevel,
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled, level >= minimumLevel else { return }

        let filename = URL(fileURLWithPath: file).lastPathComponent
        var output = ""

        if includeTimestamp {
            output += "\(dateFormatter.string(from: Date())) "
        }

        output += "\(level.prefix) [\(filename):\(line)] \(message())"

        fputs(output + "\n", stderr)
    }

    /// Logs a debug message.
    public func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message(), file: file, function: function, line: line)
    }

    /// Logs an info message.
    public func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message(), file: file, function: function, line: line)
    }

    /// Logs a warning message.
    public func warning(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, message(), file: file, function: function, line: line)
    }

    /// Logs an error message.
    public func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message(), file: file, function: function, line: line)
    }

    /// Sets the minimum log level.
    public func setLevel(_ level: LogLevel) {
        self.minimumLevel = level
    }

    /// Enables or disables logging.
    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
}

// MARK: - Convenience Global Functions

/// Logs a debug message to the shared logger.
public func logDebug(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await Logger.shared.debug(message(), file: file, function: function, line: line)
    }
}

/// Logs an info message to the shared logger.
public func logInfo(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await Logger.shared.info(message(), file: file, function: function, line: line)
    }
}

/// Logs a warning message to the shared logger.
public func logWarning(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await Logger.shared.warning(message(), file: file, function: function, line: line)
    }
}

/// Logs an error message to the shared logger.
public func logError(
    _ message: @autoclosure () -> String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task {
        await Logger.shared.error(message(), file: file, function: function, line: line)
    }
}
