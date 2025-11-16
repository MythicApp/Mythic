//
//  EpicGamesGameManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

extension EpicGamesGameManager: @MainActor StorefrontGameManager {
    @MainActor static func install(game: Game) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { return }

        try await install(game: castGame)
    }

    @MainActor static func fetchUpdateAvailability(for game: Game) async throws -> Bool {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await fetchUpdateAvailability(for: castGame)
    }

    @MainActor static func isFileVerificationRequired(for game: Game) async throws -> Bool {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { throw CocoaError(.coderInvalidValue) }

        return try await isFileVerificationRequired(for: castGame)
    }

    @MainActor static func launch(game: Game) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { return }

        try await launch(game: castGame)
    }

    @MainActor static func move(game: Game,
                                to location: URL) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { return }

        try await move(game: castGame, to: location)
    }

    @MainActor static func uninstall(game: Game,
                                     persistFiles: Bool) async throws {
        guard case .epicGames = game.storefront,
              let castGame = game as? EpicGamesGame else { return }

        try await uninstall(game: castGame, persistFiles: persistFiles)
    }
}

class EpicGamesGameManager {
    static var log: Logger { .custom(category: "EpicGamesGameManager") }

    @MainActor static func install(game: EpicGamesGame) async throws {
        <#code#>
    }

    @MainActor static func fetchUpdateAvailability(for game: EpicGamesGame) async throws -> Bool {
        <#code#>
    }

    @MainActor static func isFileVerificationRequired(for game: EpicGamesGame) async throws -> Bool {
        <#code#>
    }

    @MainActor static func launch(game: EpicGamesGame) async throws {
        <#code#>
    }

    @MainActor static func move(game: EpicGamesGame,
                                to location: URL) async throws {
        <#code#>
    }

    @MainActor static func uninstall(game: EpicGamesGame,
                                     persistFiles: Bool) async throws {
        <#code#>
    }
}
