//
//  Logger.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎]

import Foundation
import OSLog

// MARK: - Logger Extension
extension Logger {
    // MARK: Subsystem
    private static var subsystem = Bundle.main.bundleIdentifier!

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
