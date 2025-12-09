//
//  Bundle.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

// FIXME: this code is literally from mythic day 1 and sucks
/**
 Add some much-needed extensions to Bundle,
 including references to a dedicated application support folder for Mythic.
 */
extension Bundle {
    
    /**
     Dedicated 'Mythic' Application Support Folder.
     (Force-unwrappable)
     */
    static var appHome: URL? {
        if let userApplicationSupport = FileLocations.userApplicationSupport {
            let homeURL = userApplicationSupport.appending(
                path: Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "")
            
            if !FileManager.default.fileExists(atPath: homeURL.path) {
                do {
                    try FileManager.default.createDirectory(atPath: homeURL.path, withIntermediateDirectories: true, attributes: nil)
                    Logger.app.info("Creating application support directory")
                } catch {
                    Logger.app.error("Error creating application support directory: \(error.localizedDescription)")
                }
            }
            
            return homeURL
        }
        
        return nil
    }
    
    /**
     Dedicated 'Mythic' Container Folder.
     (Force-unwrappable)
     */
    static var appContainer: URL? {
        if let userContainers = FileLocations.userContainers,
           let bundleID = Bundle.main.bundleIdentifier {
            let containerURL = userContainers.appending(path: bundleID)
            let containerPath = containerURL.path
            
            if !FileManager.default.fileExists(atPath: containerPath) {
                do {
                    try FileManager.default.createDirectory(atPath: containerPath, withIntermediateDirectories: true, attributes: nil)
                    Logger.app.info("Creating Containers directory")
                } catch {
                    Logger.app.error("Error creating Containers directory: \(error.localizedDescription)")
                }
            }
            
            return containerURL
        }
        
        return nil
    }
    
    /**
     A directory within games where Mythic will download to by default.
     (Force-unwrappable)
     */
    static var appGames: URL? {
        if let games = FileLocations.globalGames {
            let appGamesURL = games.appending(path: "Mythic")
            do {
                try FileManager.default.createDirectory(
                    at: appGamesURL,
                    withIntermediateDirectories: true
                )
                return appGamesURL
            } catch {
                Logger.file.error("Unable to get games directory: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
}
