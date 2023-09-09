//
//  Logger.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/9/2023.
//

// https://www.avanderlee.com/debugging/oslog-unified-logging/

import Foundation
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    /// For custom logs that aren't worthy of being defined in an extension.
    static func custom(category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }
    
    /// For app-related logs.
    static let app = Logger(subsystem: subsystem, category: "app")
    
    /// For file-related logs.
    static let file = Logger(subsystem: subsystem, category: "file")
}
