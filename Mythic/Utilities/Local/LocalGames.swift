//
//  LocalGames.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 4/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import OSLog

final class LocalGames {
    public static let log = Logger(subsystem: Logger.subsystem, category: "localGames")
    
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
    
    static func launch(game: Mythic.Game) async throws {
        Logger.app.notice("Launching local game \(game.title) (\(game.platform?.rawValue ?? "unknown"))")
        
        guard let library = library,
              library.contains(game),
        let gamePath = game.path else {
            log.error("Unable to launch local game, not installed or missing")
            throw GameDoesNotExistError(game)
        }
        
        await MainActor.run {
            withAnimation {
                GameOperation.shared.launching = game
            }
        }
        
        try defaults.encodeAndSet(game, forKey: "recentlyPlayed")
        
        switch game.platform {
        case .macOS:
            if FileManager.default.fileExists(atPath: game.path ?? .init()) {
                workspace.open(
                    .init(filePath: gamePath),
                    configuration: {
                        let configuration = NSWorkspace.OpenConfiguration()
                        configuration.arguments = game.launchArguments
                        return configuration
                    }(),
                    completionHandler: { (_/*running app*/, error) in
                        if let error = error {
                            log.error("Error launching local macOS game \"\(game.title)\": \(error)")
                        } else {
                            log.info("Launched local macOS game \"\(game.title)\".")
                        }
                    }
                )
            } else {
                log.critical("\("The game at \(String(describing: game.path)) doesn't exist, cannot launch local macOS game!")")
            }
        case .windows:
            guard Engine.isInstalled else {
                throw Engine.NotInstalledError()
            }
            guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }
            let container = try Wine.getContainerObject(url: containerURL)
            
            let environmentVariables = try Wine.assembleEnvironmentVariables(forGame: game)

            try await Wine.execute(
                arguments: [game.path!] + game.launchArguments,
                containerURL: container.url,
                environment: environmentVariables
            )
            
        case .none:
            log.critical("game platform cannot be inferred. this is not intended behaviour")
        }
        
        if defaults.bool(forKey: "minimiseOnGameLaunch") {
            await NSApp.windows.first?.miniaturize(nil)
        }

        await MainActor.run {
            GameOperation.shared.launching = nil
        }
    }

    static func uninstall(game: Mythic.Game, deleteFiles: Bool = true) async throws {
        func performUninstall() {
            LocalGames.library?.remove(game)
            favouriteGames.remove(game.id)
        }

        guard let gamePath = game.path else {
            performUninstall()
            throw CocoaError(.fileNoSuchFile)
        }

        if files.fileExists(atPath: gamePath), deleteFiles {
            try files.removeItem(atPath: gamePath)
            performUninstall()
        }

        if let recent = try? defaults.decodeAndGet(Mythic.Game.self, forKey: "recentlyPlayed"),
           recent == game {
            defaults.removeObject(forKey: "recentlyPlayed")
        }
    }
}
