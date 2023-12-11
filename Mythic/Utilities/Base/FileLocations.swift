//
//  FileLocations.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/11/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import Foundation
import OSLog

private let files = FileManager.default

class FileLocations {
    static let globalApplications: URL? = {
        do {
            return try files.url(for: .applicationDirectory,
                                 in: .localDomainMask,
                                 appropriateFor: nil,
                                 create: false)
        } catch {
            Logger.file.error("Unable to get global Applications directory: \(error)")
        }
        
        return nil
    }()
    
    /// A directory in global applications where games should be located.
    /// (Force-unwrappable)
    static let globalGames: URL? = {
        if let globalApplications = globalApplications {
            let gamesURL = globalApplications.appending(path: "Games")
            do {
                try files.createDirectory(
                    at: gamesURL,
                    withIntermediateDirectories: false
                )
                return gamesURL
            } catch {
                Logger.file.error("Unable to get games directory: \(error)")
            }
        } // no else block, error is handled already
        
        return nil
    }()
    
    /// The current user's Application Support directory.
    /// (Force-unwrappable)
    static let userApplicationSupport: URL? = {
        do {
            return try files.url(for: .applicationSupportDirectory,
                                 in: .userDomainMask,
                                 appropriateFor: nil,
                                 create: false)
        } catch {
            Logger.file.error("Unable to get Application Support directory: \(error)")
        }
        
        return nil
    }()
    
    /// The current user's Containers directory.
    /// (Force-unwrappable)
    static let userContainers: URL? = {
        do {
            return try files.url(for: .libraryDirectory,
                                 in: .userDomainMask,
                                 appropriateFor: nil,
                                 create: false)
            .appending(path: "Containers")
        } catch {
            Logger.file.error("Unable to get Containers directory: \(error)")
        }
        
        return nil
    }()
}
