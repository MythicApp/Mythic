//
//  Logger.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 16/9/2023.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import OSLog

extension Logger {
    nonisolated(unsafe) static var subsystem = Bundle.main.bundleIdentifier!
    
    /**
     Returns a custom logger instance with the specified category.
     
     - Parameter category: The category for the custom logger.
     - Returns: A custom logger instance.
     */
    static func custom(category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }
    
    /// Logger instance for network-related logs.
    static let network = custom(category: "network")
    
    /// Logger instance for app-related logs.
    static let app = custom(category: "app")
    
    /// Logger instance for file-related logs.
    static let file = custom(category: "file")
}
