//
//  Logger.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 16/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

// MARK: - Logger Extension
extension Logger {
    // MARK: Subsystem
    nonisolated(unsafe) static var subsystem = Bundle.main.bundleIdentifier!

    // MARK: - Custom Logger Method
    /**
     Returns a custom logger instance with the specified category.

     - Parameter category: The category for the custom logger.
     - Returns: A custom logger instance.
     */
    static func custom(category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }

    // MARK: Network Logger
    /// Logger instance for network-related logs.
    static let network = custom(category: "network")

    // MARK: App Logger
    /// Logger instance for app-related logs.
    static let app = custom(category: "app")

    // MARK: File Logger
    /// Logger instance for file-related logs.
    static let file = custom(category: "file")
}
