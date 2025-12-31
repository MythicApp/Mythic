//
//  EpicGamesGameManager.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 16/11/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import OSLog

extension EpicGamesGameManager: StorefrontGameManager {
    @MainActor static func importGame(_ game: Game, platform: Game.Platform, at location: URL) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        // FIXME: last path component is deleted from location, since Legendary requires the game's enclosing folder URL.
        try await importGame(castGame, in: location.deletingLastPathComponent(), platform: platform)
    }
    
    static func install(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await install(game: castGame, qualityOfService: qualityOfService)
    }

    static func update(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await update(game: castGame, qualityOfService: qualityOfService)
    }

    static func repair(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await repair(game: castGame, qualityOfService: qualityOfService)
    }

    static func fetchUpdateAvailability(for game: Game) throws -> Bool {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try fetchUpdateAvailability(for: castGame)
    }

    static func isFileVerificationRequired(for game: Game) throws -> Bool {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try isFileVerificationRequired(for: castGame)
    }

    @MainActor static func launch(game: Game) async throws -> GameOperation {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await Task(operation: { try await launch(game: castGame) }).value
    }

    @MainActor static func move(game: Game,
                                to location: URL) async throws -> GameOperation {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await Task(operation: { try await move(game: castGame, to: location) }).value
    }

    @MainActor static func uninstall(game: Game,
                                     persistFiles: Bool) async throws -> GameOperation {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await uninstall(game: castGame, persistFiles: persistFiles)
    }
}

final class EpicGamesGameManager {
    static var log: Logger { .custom(category: "EpicGamesGameManager") }

    @discardableResult
    static func install(game: EpicGamesGame,
                        forPlatform platform: Game.Platform,
                        qualityOfService: QualityOfService,
                        optionalPackIDs: [String] = .init(),
                        baseDirectoryURL: URL? = UserDefaults.standard.url(forKey: "installBaseURL")) async throws -> GameOperation {
        return try await Legendary.install(game: game,
                                           forPlatform: platform,
                                           qualityOfService: qualityOfService,
                                           optionalPackIDs: optionalPackIDs,
                                           baseDirectoryURL: baseDirectoryURL)
    }

    @discardableResult
    static func update(game: EpicGamesGame, qualityOfService: QualityOfService) async throws -> GameOperation {
        return try await Legendary.update(game: game, qualityOfService: qualityOfService)
    }

    @discardableResult
    static func repair(game: EpicGamesGame, qualityOfService: QualityOfService) async throws -> GameOperation {
        return try await Legendary.repair(game: game, qualityOfService: qualityOfService)
    }

    static func fetchUpdateAvailability(for game: EpicGamesGame) throws -> Bool {
        return try Legendary.fetchUpdateAvailability(gameID: game.id)
    }

    static func isFileVerificationRequired(for game: EpicGamesGame) throws -> Bool {
        return try Legendary.isFileVerificationRequired(gameID: game.id)
    }

    @discardableResult
    static func launch(game: EpicGamesGame) async throws -> GameOperation {
        return try await Legendary.launch(game: game)
    }

    @discardableResult
    static func move(game: EpicGamesGame,
                     to newLocation: URL) async throws -> GameOperation {
        return try await Legendary.move(game: game, to: newLocation)
    }

    @discardableResult
    static func uninstall(game: EpicGamesGame,
                          persistFiles: Bool,
                          runUninstallerIfPossible: Bool = true) async throws -> GameOperation {
        return try await Legendary.uninstall(game: game,
                                      persistFiles: persistFiles,
                                      runUninstallerIfPossible: runUninstallerIfPossible)
    }
    
    @MainActor static func importGame(_ game: EpicGamesGame,
                                      in enclosingDirectory: URL,
                                      repairIfNecessary: Bool = true,
                                      withDLCs: Bool = true,
                                      platform: Game.Platform) async throws {
        try await Legendary.importGame(game,
                                       in: enclosingDirectory,
                                       repairIfNecessary: repairIfNecessary,
                                       withDLCs: withDLCs,
                                       platform: platform)
    }
}
