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
    static func install(game: Game, qos: QualityOfService) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await install(game: castGame, qos: qos)
    }

    static func update(game: Game, qos: QualityOfService) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await update(game: castGame, qos: qos)
    }

    static func repair(game: Game, qos: QualityOfService) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await repair(game: castGame, qos: qos)
    }

    static func fetchUpdateAvailability(for game: Game) async throws -> Bool {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await fetchUpdateAvailability(for: castGame)
    }

    static func isFileVerificationRequired(for game: Game) async throws -> Bool {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await isFileVerificationRequired(for: castGame)
    }

    @MainActor static func launch(game: Game) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await launch(game: castGame)
    }

    @MainActor static func move(game: Game,
                     to location: URL) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await move(game: castGame, to: location)
    }

    static func uninstall(game: Game,
                          persistFiles: Bool) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        try await uninstall(game: castGame, persistFiles: persistFiles)
    }
}

class EpicGamesGameManager {
    static var log: Logger { .custom(category: "EpicGamesGameManager") }

    static func install(game: EpicGamesGame,
                        qos: QualityOfService,
                        optionalPacks: [String] = .init(),
                        gameDirectoryURL: URL? = Bundle.appGames) async throws {
        try await Legendary.install(game: game,
                                    qos: qos,
                                    optionalPacks: optionalPacks,
                                    gameDirectoryURL: gameDirectoryURL)
    }

    static func update(game: EpicGamesGame, qos: QualityOfService) async throws {
        try await Legendary.update(game: game, qos: qos)
    }

    static func repair(game: EpicGamesGame, qos: QualityOfService) async throws {
        try await Legendary.repair(game: game, qos: qos)
    }

    static func fetchUpdateAvailability(for game: EpicGamesGame) async throws -> Bool {
        try await Legendary.fetchUpdateAvailability(for: game)
    }

    static func isFileVerificationRequired(for game: EpicGamesGame) async throws -> Bool {
        try await Legendary.isFileVerificationRequired(for: game)
    }

    @MainActor static func launch(game: EpicGamesGame) async throws {
        try await Legendary.launch(game: game)
    }

    @MainActor static func move(game: EpicGamesGame,
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
