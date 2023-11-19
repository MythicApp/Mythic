//
//  Bundle.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/9/2023.
//

import Foundation
import OSLog

private let files = FileManager.default

/// Add some much-needed extensions to Bundle,
/// including references to a dedicated application support folder for Mythic.
extension Bundle {

    /// Dedicated 'Mythic' Application Support Folder.
    /// (Force-unwrappable)
    static let appHome: URL? = {
        if let userApplicationSupport = FileLocations.userApplicationSupport {
            let homeURL = userApplicationSupport.appending(
                path: Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "")
            let homePath = homeURL.path

            if !files.fileExists(atPath: homePath) {
                do {
                    try files.createDirectory(atPath: homePath, withIntermediateDirectories: true, attributes: nil)
                    Logger.app.info("Creating application support directory")
                } catch {
                    Logger.app.error("Error creating application support directory: \(error)")
                }
            }

            return homeURL
        }

        return nil
    }()

    /// Dedicated 'Mythic' Container Folder. (Mythic is a sandboxed application.)
    /// (Force-unwrappable)
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
                    Logger.app.error("Error creating Containers directory: \(error)")
                }
            }

            return containerURL
        }

        return nil
    }()

    /// A directory within games where Mythic will download to by default.
    /// (Force-unwrappable)
    static let appGames: URL? = {
        if let games = FileLocations.globalGames {
            let appGamesURL = games.appending(path: "Mythic")
            do {
                try files.createDirectory(
                    at: appGamesURL,
                    withIntermediateDirectories: false
                )
                return appGamesURL
            } catch {
                Logger.file.error("Unable to get games directory: \(error)")
            }
        } // no else block, error is handled already

        return nil
    }()
}
