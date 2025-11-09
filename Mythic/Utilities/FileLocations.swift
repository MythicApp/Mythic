//
//  FileLocations.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/11/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

final class FileLocations {
    /** The global Applications directory.
     
     - Returns: An optional URL representing the global Applications directory.
     */
    static let globalApplications: URL? = {
        do {
            return try files.url(
                for: .applicationDirectory,
                in: .localDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            Logger.file.error("Unable to get global Applications directory: \(error.localizedDescription)")
        }
        
        return nil
    }()

    /** A directory in global applications where games should be located.
     (Force-unwrappable)
     
     - Returns: An optional URL representing the global Games directory.
     */
    static let globalGames: URL? = {
        if let globalApplications = globalApplications {
            let gamesURL = globalApplications.appendingPathComponent("Games")
            do {
                try files.createDirectory(
                    at: gamesURL,
                    withIntermediateDirectories: true
                )
                return gamesURL
            } catch {
                Logger.file.error("Unable to get user's games directory: \(error.localizedDescription)")
            }
        } // no else block, error is handled already
        
        return nil
    }()

    /** The current user's Application Support directory.
     
     (Force-unwrappable)
     
     - Returns: An optional URL representing the current user's Application Support directory.
     */
    static let userApplicationSupport: URL? = {
        do {
            return try files.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask, // to remain individual
                appropriateFor: nil,
                create: false
            )
        } catch {
            Logger.file.error("Unable to get user's Application Support directory: \(error.localizedDescription)")
        }
        
        return nil
    }()
    
    static func isWritableFolder(url: URL) -> Bool { // does the same as files.isWritableFile, just a second option
        let tempFileName = "_Mythic\(UUID().uuidString).temp"
        let tempFileURL = url.appendingPathComponent(tempFileName)

        do {
            try String().write(to: tempFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: tempFileURL)
            return true
        } catch {
            return false
        }
    }

    static let userLibrary: URL? = {
        do {
            return try files.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            Logger.file.error("Unable to get user's Library directory: \(error.localizedDescription)")
        }

        return nil
    }()
    
    /** The current user's Containers directory.
     
     (Force-unwrappable)
     
     - Returns: An optional URL representing the current user's Containers directory.
     */
    static let userContainers: URL? = {
        do {
            return try files.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            .appendingPathComponent("Containers")
        } catch {
            Logger.file.error("Unable to get user's Containers directory: \(error.localizedDescription)")
        }
        
        return nil
    }()
}
