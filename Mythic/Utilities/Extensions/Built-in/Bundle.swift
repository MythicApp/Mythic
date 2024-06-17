//
//  Bundle.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

/**
 Add some much-needed extensions to Bundle,
 including references to a dedicated application support folder for Mythic.
 */
extension Bundle {
    
    /**
     Dedicated 'Mythic' Application Support Folder.
     (Force-unwrappable)
     */
    static let appHome: URL? = {
        if let userApplicationSupport = FileLocations.userApplicationSupport {
            let homeURL = userApplicationSupport.appending(
                path: Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "")
            
            if !files.fileExists(atPath: homeURL.path) {
                do {
                    try files.createDirectory(atPath: homeURL.path, withIntermediateDirectories: true, attributes: nil)
                    Logger.app.info("Creating application support directory")
                } catch {
                    Logger.app.error("Error creating application support directory: \(error.localizedDescription)")
                }
            }
            
            return homeURL
        }
        
        return nil
    }()
    
    /**
     Dedicated 'Mythic' Container Folder.
     (Force-unwrappable)
     */
    static let appContainer: URL? = {
        if let userContainers = FileLocations.userContainers,
           let bundleID = Bundle.main.bundleIdentifier {
            let containerURL = userContainers.appending(path: bundleID)
            let containerPath = containerURL.path
            
            if !files.fileExists(atPath: containerPath) {
                do {
                    try files.createDirectory(atPath: containerPath, withIntermediateDirectories: true, attributes: nil)
                    Logger.app.info("Creating Containers directory")
                } catch {
                    Logger.app.error("Error creating Containers directory: \(error.localizedDescription)")
                }
            }
            
            return containerURL
        }
        
        return nil
    }()
    
    /**
     A directory within games where Mythic will download to by default.
     (Force-unwrappable)
     */
    static let appGames: URL? = {
        if let games = FileLocations.globalGames {
            let appGamesURL = games.appending(path: "Mythic")
            do {
                try files.createDirectory(
                    at: appGamesURL,
                    withIntermediateDirectories: true
                )
                return appGamesURL
            } catch {
                Logger.file.error("Unable to get games directory: \(error.localizedDescription)")
            }
        }
        
        return nil
    }()
}
