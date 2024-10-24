//
//  AppLogger.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

import Foundation
import OSLog

public struct AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "Mythic"
    #if DEBUG
    static let logLevel = LogLevel.debug
    #else
    static let logLevel = LogLevel.info
    #endif

    enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
    }

    #if !DEBUG
    private var logger: Logger
    #endif
    private var category: String

    /// The category should be Class.self
    public init(category: Any) {
        self.category = "\(category)"
        #if !DEBUG
        self.logger = Logger(subsystem: AppLogger.subsystem, category: String(describing: category))
        #endif
    }

    #if DEBUG
    private func log(_ message: String, level: LogLevel) {
        if level.rawValue <= AppLogger.logLevel.rawValue { return }
        switch level {
        case .debug:
            print("\u{1b}[0;1;34m[🐞DEBUG \(self.category)]\u{1b}[0;34m \(message)\u{1b}[0")
        case .info:
            print("\u{1b}[0;1;32m[ℹ️INFO \(self.category)]\u{1b}[0;32m \(message)\u{1b}[0")
        case .warning:
            print("\u{1b}[0;1;33m[⚠️WARNING \(self.category)]\u{1b}[0;33m \(message)\u{1b}[0")
        case .error:
            print("\u{1b}[0;1;31m[🚨ERROR \(self.category)]\u{1b}[0;31m \(message)\u{1b}[0")
        }
    }
    #else
    private func log(_ message: String, level: LogLevel) {
        if level.rawValue < AppLogger.logLevel.rawValue { return }
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }
    #endif

    public func debug(_ message: String) {
        log(message, level: .debug)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func warning(_ message: String) {
        log(message, level: .warning)
    }
}
