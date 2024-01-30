//
//  WhiskyInterface.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

// MARK: - WhiskyInterface Class
/**
 A class providing an interface for interacting with Whisky-related functionality.
 
 - Note: `WhiskyCmd` is not fully implemented.
 */
class WhiskyInterface {
    // MARK: Logging
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "whiskyInterface"
    )
    
    // MARK: - Get Bottles Method
    /**
     Retrieves a list of bottles.
     
     - Returns: An array of `Bottle` objects.
     */
    static func getBottles() -> [Bottle] {
        var bottles = [Bottle]()
        
        if let bottlePaths = getBottlePaths() {
            for path in bottlePaths {
                if let bottleURL = URL(string: path), // use fileURL: alternatively
                   let metadata = getBottleMetadata(bottleURL: bottleURL) {
                    let bottle = Bottle(path: path, metadata: metadata)
                    bottles.append(bottle)
                }
            }
        }
        
        return bottles
    }
    
    // MARK: - Get Bottle Paths Method
    /**
     Retrieves the paths of bottles.
     
     - Returns: An array of strings representing bottle paths, or `nil` if unsuccessful.
     */
    static func getBottlePaths() -> [String]? {
        let bottleVMURL = URL(filePath: "/Users/blackxfiied/Library/Containers/com.isaacmarovitz.Whisky/BottleVM.plist")
        
        if let bottleVMData = try? Data(contentsOf: bottleVMURL),
           let plist = try? PropertyListSerialization.propertyList(from: bottleVMData, format: nil) as? [String: Any],
           let paths = plist["paths"] as? [[String: String]] {
            return paths.compactMap { $0.values.first }
        } else {
            log.warning("Unable to get bottle paths.")
        }
        
        return nil
    }
    
    // MARK: - Get Bottle Metadata Method
    /**
     Retrieves metadata for a given bottle URL.
     
     - Parameter bottleURL: The URL of the bottle.
     - Returns: A dictionary containing the metadata, or `nil` if unsuccessful.
     */
    static func getBottleMetadata(bottleURL: URL) -> [String: Any]? {
        if let metadata = try? Data(contentsOf: bottleURL.appending(path: "Metadata.plist")),
           let plist = try? PropertyListSerialization.propertyList(from: metadata, format: nil) {
            return plist as? [String: Any]
        } else {
            log.warning("Unable to get bottle metadata.")
        }
        
        return nil
    }
}
