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

    static func custom(category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }

    static let network = custom(category: "network")
    static let app = custom(category: "app")
    static let file = custom(category: "file")
}
