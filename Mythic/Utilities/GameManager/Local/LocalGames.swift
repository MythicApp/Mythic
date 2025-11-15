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

// TODO: refactor
final class LocalGames {
    public static let log = Logger(subsystem: Logger.subsystem, category: "localGames")
    
    // TODO: DocC
    static var library: Set<Mythic.LegacyGame>? {
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
    
    static func launch(game: Mythic.LegacyGame) async throws {
        Logger.app.notice("Launching local game \(game.title) (\(game.platform.rawValue))")
        
        guard let library = library,
              library.contains(game),
              let gameLocation = game.location else {
            log.error("Unable to launch local game, not installed or missing")
            throw GameDoesNotExistError(game)
        }

        await MainActor.run {
            withAnimation {
                LegacyGameOperation.shared.launching = game
            }
        }
        
        try defaults.encodeAndSet(game, forKey: "recentlyPlayed")
        
        switch game.platform {
        case .macOS:
            let openConfiguration: NSWorkspace.OpenConfiguration = .init()
            openConfiguration.arguments = game.launchArguments

            if FileManager.default.fileExists(atPath: gameLocation.path) {
                workspace.open(gameLocation, configuration: openConfiguration) { (_/*running app*/, error) in
                    guard error == nil else {
                        log.error("Error launching local macOS game \"\(game.title)\": \(error)")
                        return
                    }

                    log.info("Launched local macOS game \"\(game.title)\".")
                }
            } else {
                log.critical("\("The game at \(gameLocation) doesn't exist, cannot launch local macOS game!")")
            }
        case .windows:
            guard Engine.isInstalled else {
                throw Engine.NotInstalledError()
            }
            guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }
            let container = try Wine.getContainerObject(url: containerURL)

            let environmentVariables = try Wine.assembleEnvironmentVariables(forGame: game)

            try await Wine.execute(
                arguments: [gameLocation.path] + game.launchArguments,
                containerURL: container.url,
                environment: environmentVariables
            )
        }

        if defaults.bool(forKey: "minimiseOnGameLaunch") {
            await NSApp.windows.first?.miniaturize(nil)
        }

        await MainActor.run {
            LegacyGameOperation.shared.launching = nil
        }
    }

    static func uninstall(game: Mythic.LegacyGame, deleteFiles: Bool = true) async throws {
        func performUninstall() {
            LocalGames.library?.remove(game)
            favouriteGames.remove(game.id)
        }

        guard let gameLocation = game.location else {
            performUninstall()
            throw CocoaError(.fileNoSuchFile)
        }

        if files.fileExists(atPath: gameLocation.path), deleteFiles {
            try files.removeItem(at: gameLocation)
            performUninstall()
        }

        if let recent = try? defaults.decodeAndGet(Mythic.LegacyGame.self, forKey: "recentlyPlayed"),
           recent == game {
            defaults.removeObject(forKey: "recentlyPlayed")
        }
    }
}
