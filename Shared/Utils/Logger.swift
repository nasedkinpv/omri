//
//  Logger.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Structured logging utility for development and debugging
//  Pattern: Singleton with static methods
//

import Foundation

/// Log level severity
enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// Structured logging utility
///
/// Usage:
/// ```
/// Logger.debug("Detailed debugging info")
/// Logger.info("General information")
/// Logger.warning("Warning message")
/// Logger.error("Error occurred")
/// ```
struct Logger {

    // MARK: - Configuration

    /// Enable/disable logging based on build configuration
    nonisolated private static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Logging Methods

    /// Log a debug message (only in DEBUG builds)
    static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    /// Log an informational message
    static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    /// Log a warning message
    static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    /// Log an error message
    static func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    // MARK: - Private Implementation

    /// Core logging function
    /// Note: nonisolated to allow calls from any context (including audio processing callbacks)
    nonisolated private static func log(
        _ message: String,
        level: LogLevel,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled else { return }

        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let timestamp = formatTimestamp()

        // Format: [TIMESTAMP] LEVEL [File:Line] Function - Message
        print("[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(function) - \(message)")
    }

    /// Format current timestamp for logging
    nonisolated private static func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log with custom context (e.g., "AudioManager", "SSH")
    /// Note: nonisolated to allow calls from any context (including audio processing callbacks)
    nonisolated static func log(
        _ message: String,
        context: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let contextMessage = "[\(context)] \(message)"
        log(contextMessage, level: level, file: file, function: function, line: line)
    }
}
