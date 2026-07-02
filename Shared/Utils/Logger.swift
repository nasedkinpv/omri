//
//  Logger.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Thin shim over os.Logger (unified logging: visible in Console.app,
//  filterable by subsystem/category, near-zero cost when not captured)
//

import Foundation
import os

enum LogLevel {
    case debug, info, warning, error

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Omri"

    /// Log with context (e.g., "Audio", "SSH"); context maps to the os.Logger category.
    /// nonisolated-safe: callable from any thread, including audio callbacks.
    static func log(_ message: String, context: String, level: LogLevel = .info) {
        #if DEBUG
        os.Logger(subsystem: subsystem, category: context)
            .log(level: level.osLogType, "\(message, privacy: .public)")
        #endif
    }
}
