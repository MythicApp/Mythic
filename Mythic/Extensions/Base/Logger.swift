//
//  Logger.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
