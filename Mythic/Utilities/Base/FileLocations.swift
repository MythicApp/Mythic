//
//  FileLocations.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/11/2023.
//

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
