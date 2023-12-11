//
//  WhiskyInterface.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/10/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// WhiskyCmd not fully implemented.

import Foundation
import OSLog

class WhiskyInterface {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "whiskyInterface"
    )
    
    static func getBottles() -> [Bottle] {
        var bottles = [Bottle]()
        
        if let bottlePaths = getBottlePaths() {
            for path in bottlePaths {
                if let bottleURL = URL(string: path),
                   let metadata = getBottleMetadata(bottleURL: bottleURL) {
                    let bottle = Bottle(path: path, metadata: metadata)
                    bottles.append(bottle)
                }
            }
        }
        
        return bottles
    }
    
    static func getBottlePaths() -> [String]? {
        let bottleVMURL = URL(filePath: "/Users/blackxfiied/Library/Containers/com.isaacmarovitz.Whisky/BottleVM.plist")
        
        if let bottleVMData = try? Data(contentsOf: bottleVMURL),
           let plist = try? PropertyListSerialization.propertyList(from: bottleVMData, format: nil) as? [String: Any],
           let paths = plist["paths"] as? [[String: String]] {
            return paths.compactMap { $0.values.first }
        } else { log.warning("Unable to get bottle paths.") }
        
        return nil
    }
    
    static func getBottleMetadata(bottleURL: URL) -> [String: Any]? {
        if let metadata = try? Data(contentsOf: bottleURL.appending(path: "Metadata.plist")),
           let plist = try? PropertyListSerialization.propertyList(from: metadata, format: nil) {
            return plist as? [String: Any]
        } else { log.warning("Unable to get bottle metadata.") }
        
        return nil
    }
}
