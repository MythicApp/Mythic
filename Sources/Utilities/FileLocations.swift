//
//  FileLocations.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/11/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

// MARK: - File Locations Class
final class FileLocations {
    
    // MARK: - Functions
    
    // MARK: - Global Applications Directory
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
    
    // MARK: - Global Games Directory
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
                Logger.file.error("Unable to get games directory: \(error.localizedDescription)")
            }
        } // no else block, error is handled already
        
        return nil
    }()
    
    // MARK: - User Application Support Directory
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
            Logger.file.error(" Unable to get Application Support directory: \(error.localizedDescription)")
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
    
    // MARK: - User Containers Directory
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
            Logger.file.error("Unable to get Containers directory: \(error.localizedDescription)")
        }
        
        return nil
    }()
    
    // MARK: - Other
    
    struct FileDoesNotExistError: LocalizedError {
        init(_ fileURL: URL?) {
            self.fileURL = fileURL
        }
        
        let fileURL: URL?
        var errorDescription: String? = "The file/folder doesn't exist."
    }
    
    struct FileNotModifiableError: LocalizedError { 
        init(_ fileURL: URL?) {
            self.fileURL = fileURL
        }
        
        let fileURL: URL?
        var errorDescription: String? = "The file/folder isn't modifiable."
    }
}
