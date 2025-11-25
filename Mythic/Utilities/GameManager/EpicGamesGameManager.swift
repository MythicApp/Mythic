//
//  EpicGamesGameManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

extension EpicGamesGameManager: StorefrontGameManager {
    static func install(game: Game, qualityOfService: QualityOfService) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await install(game: castGame, qualityOfService: qualityOfService)
    }

    static func update(game: Game, qualityOfService: QualityOfService) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await update(game: castGame, qualityOfService: qualityOfService)
    }

    static func repair(game: Game, qualityOfService: QualityOfService) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await repair(game: castGame, qualityOfService: qualityOfService)
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

    @MainActor static func launch(game: Game) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await Task(operation: { try await launch(game: castGame) }).value
    }

    @MainActor static func move(game: Game,
                                to location: URL) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await Task(operation: { try await move(game: castGame, to: location) }).value
    }

    @MainActor static func uninstall(game: Game,
                                     persistFiles: Bool) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await uninstall(game: castGame, persistFiles: persistFiles)
    }
}

final class EpicGamesGameManager {
    static var log: Logger { .custom(category: "EpicGamesGameManager") }

    static func install(game: EpicGamesGame,
                        forPlatform platform: Game.Platform,
                        qualityOfService: QualityOfService,
                        optionalPacks: [String] = .init(),
                        gameDirectoryURL: URL? = defaults.url(forKey: "installBaseURL")) async throws {
        try await Legendary.install(game: game,
                                    forPlatform: platform,
                                    qualityOfService: qualityOfService,
                                    optionalPacks: optionalPacks,
                                    gameDirectoryURL: gameDirectoryURL)
    }

    static func update(game: EpicGamesGame, qualityOfService: QualityOfService) async throws {
        try await Legendary.update(game: game, qualityOfService: qualityOfService)
    }

    static func repair(game: EpicGamesGame, qualityOfService: QualityOfService) async throws {
        try await Legendary.repair(game: game, qualityOfService: qualityOfService)
    }

    static func fetchUpdateAvailability(for game: EpicGamesGame) throws -> Bool {
        try Legendary.fetchUpdateAvailability(gameID: game.id)
    }

    static func isFileVerificationRequired(for game: EpicGamesGame) throws -> Bool {
        try Legendary.isFileVerificationRequired(gameID: game.id)
    }

    static func launch(game: EpicGamesGame) async throws {
        try await Legendary.launch(game: game)
    }

    static func move(game: EpicGamesGame,
                     to newLocation: URL) async throws {
        try await Legendary.move(game: game, to: newLocation)
    }

    static func uninstall(game: EpicGamesGame,
                          persistFiles: Bool,
                          runUninstallerIfPossible: Bool = true) async throws {
        try await Legendary.uninstall(game: game,
                                      persistFiles: persistFiles,
                                      runUninstallerIfPossible: runUninstallerIfPossible)
    }
}
