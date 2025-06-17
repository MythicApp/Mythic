//
//  AppLoggerModel.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

import Foundation
import OSLog

public struct AppLoggerModel: Sendable {
    #if DEBUG
    static let logLevel = LogLevel.debug
    #else
    static let logLevel = LogLevel.info
    #endif

    enum LogLevel: Int, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
    }

    private var logger: Logger
    private var category: String

    /// The category should be Class.self
    public init(category: Any) {
        self.category = "\(category)"
        self.logger = Logger(subsystem: AppDelegate.bundleIdentifier, category: String(describing: category))
    }

    #if !DEBUG
    private func log(_ message: String, level: LogLevel) {
        if level.rawValue < Self.logLevel.rawValue { return }
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
    #else
    private func log(_ message: String, level: LogLevel) {
        if level.rawValue < Self.logLevel.rawValue { return }
        switch level {
        case .debug:
            logger.debug("[DBG:\(self.category)] \(message)")
        case .info:
            logger.info("[INF:\(self.category)] \(message)")
        case .warning:
            logger.warning("[WRN:\(self.category)] \(message)")
        case .error:
            logger.error("[ERR:\(self.category)] \(message)")
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
    
    public func error(_ message: String) {
        log(message, level: .error)
    }
}
