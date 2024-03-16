//
//  LocalGames.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 4/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI
import OSLog

class LocalGames {
    public static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "localGames")
    
    // TODO: DocC
    static var library: Set<Mythic.Game>? { // FIXME: is there a way to init it at the top
        get {
            if let library = defaults.object(forKey: "localGamesLibrary") as? Data {
                do {
                    return try PropertyListDecoder().decode(Set.self, from: library)
                } catch {
                    Logger.app.error("Unable to retrieve local game library: \(error.localizedDescription)")
                    return nil
                }
            } else {
                Logger.app.warning("Local games library does not exist, returning blank array")
                return .init()
            }
        }
        set {
            do {
                defaults.set(
                    try PropertyListEncoder().encode(newValue),
                    forKey: "localGamesLibrary"
                )
            } catch {
                Logger.app.error("Unable to set local game library: \(error.localizedDescription)")
            }
        }
    }
    
    static func launch(game: Mythic.Game, bottle: Wine.Bottle) async throws { // TODO: be able to tell when game is runnning
        Logger.app.notice("Launching local game \(game.title) (\(game.platform?.rawValue ?? "unknown"))")
        
        guard let library = library,
              library.contains(game) else {
            log.error("Unable to launch local game, not installed or missing") // TODO: add alert in unified alert system
            throw GameDoesNotExistError(game)
        }
        
        switch game.platform {
        case .macOS:
            if FileManager.default.fileExists(atPath: game.path ?? .init()) {
                workspace.open(
                    URL(filePath: game.path ?? .init()),
                    configuration: NSWorkspace.OpenConfiguration(),
                    completionHandler: { (_/*game*/, error) in
                        if let error = error {
                            log.error("Error launching local macOS game \"\(game.title)\": \(error)")
                        } else {
                            log.info("Launched local macOS game \"\(game.title)\": \(error)")
                        }
                    }
                )
            } else {
                log.critical("\("The game at \(game.path ?? "[Unknown]") doesn't exist, cannot launch local macOS game!")")
            }
        case .windows:
            guard Libraries.isInstalled() else { throw Libraries.NotInstalledError() }
            guard Wine.bottleExists(bottleURL: bottle.url) else { throw Wine.BottleDoesNotExistError() }
            
            GameModification.shared.launching = game
            defaults.set(try PropertyListEncoder().encode(game), forKey: "recentlyPlayed")
            
            try await Wine.command(
                args: [game.path!],
                identifier: "launch_\(game.title)",
                bottleURL: bottle.url, // TODO: whichever prefix is set for it or as default
                additionalEnvironmentVariables: [
                    "MTL_HUD_ENABLED": bottle.settings.metalHUD ? "1" : "0",
                    "WINEMSYNC": bottle.settings.msync ? "1" : "0"
                ]
            )
            
        case .none: do { /* TODO: Error */ }
        }
        
        GameModification.shared.launching = nil
    }
}
