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

final class LocalGames {
    public static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "localGames")
    
    // TODO: DocC
    static var library: Set<Mythic.Game>? {
        get {
            return (try? defaults.decodeAndGet(Set.self, forKey: "localGamesLibrary")) ?? .init()
        }
        set {
            do {
                try defaults.encodeAndSet(newValue, forKey: "localGamesLibrary")
            } catch {
                Logger.app.error("Unable to set to local games library: \(error.localizedDescription)")
            }
        }
    }
    
    static func launch(game: Mythic.Game) async throws { // TODO: be able to tell when game is runnning
        Logger.app.notice("Launching local game \(game.title) (\(game.platform?.rawValue ?? "unknown"))")
        
        guard let library = library,
              library.contains(game) else {
            log.error("Unable to launch local game, not installed or missing")
            throw GameDoesNotExistError(game)
        }
        
        Task { @MainActor in
            GameOperation.shared.launching = game
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
                            log.info("Launched local macOS game \"\(game.title)\".")
                        }
                    }
                )
            } else {
                log.critical("\("The game at \(game.path ?? "[Unknown]") doesn't exist, cannot launch local macOS game!")")
            }
        case .windows: // FIXME: unneeded unification
            guard Engine.exists else { throw Engine.NotInstalledError() }
            guard let bottleURL = game.bottleURL else { throw Wine.BottleDoesNotExistError() } // FIXME: Bottle Revamp
            let bottle = try Wine.getBottleObject(url: bottleURL)
            
            try defaults.encodeAndSet(game, forKey: "recentlyPlayed")
            
            try await Wine.command(
                arguments: [game.path!] + game.launchArguments,
                identifier: "launch_\(game.title)",
                bottleURL: bottle.url,
                environment: [
                    "MTL_HUD_ENABLED": bottle.settings.metalHUD ? "1" : "0",
                    "WINEMSYNC": bottle.settings.msync ? "1" : "0"
                ]
            ) { _ in }
            
        case .none: do { /* TODO: Error */ }
        }
        
        Task { @MainActor in
            GameOperation.shared.launching = nil
        }
    }
}
