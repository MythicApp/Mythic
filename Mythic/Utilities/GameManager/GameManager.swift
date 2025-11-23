//
//  GameManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

/// Protocol defining common game manager functionality across different game sources
protocol GameManager {
    /// Logger instance for the game manager
    static var log: Logger { get }

    /// Open a game, provided it's installed.
    @MainActor static func launch(game: Game) async throws

    /**
     Move a game to a new location
     - Parameters:
        - game: The game to move
        - location: The target file location of the move operation.
     */
    @MainActor static func move(game: Game, to newLocation: URL) async throws

    /**
     Uninstall a game
     - Parameters:
        - game: The game to uninstall.
        - persistFiles: Whether to delete the game files from disk.
     */
    @MainActor static func uninstall(game: Game, persistFiles: Bool) async throws
}

/// Protocol defining additional game manager functionality for storefronts (Epic, Steam, etc.)
protocol StorefrontGameManager: GameManager {
    /// Update the specified game, if possible.
    static func install(game: Game, qualityOfService: QualityOfService) async throws

    /// Update the specified game, if possible.
    static func update(game: Game, qualityOfService: QualityOfService) async throws

    /// Repair the specified game, if necessary.
    static func repair(game: Game, qualityOfService: QualityOfService) async throws

    /// Check if a game update is available.
    static func fetchUpdateAvailability(for game: Game) throws -> Bool

    /// Check if a game's files require verification.
    static func isFileVerificationRequired(for game: Game) throws -> Bool
}
