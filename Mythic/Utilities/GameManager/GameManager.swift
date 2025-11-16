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

    /// Open a game
    @MainActor static func launch(game: Game) async throws

    /**
     Move a game to a new location
     - Parameters:
        - game: The game to move
        - location: The target file location of the move operation.
     */
    @MainActor static func move(game: Game, to location: URL) async throws

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
    /**
     Install, update, or repair a game
     - Parameters:
        - arguments: Installation configuration and parameters
        - Throws: Various installation errors
     */
    static func install(game: Game) async throws

    /// Check if a game update is available.
    static func fetchUpdateAvailability(for game: Game) async throws -> Bool

    /**
     Check if a game needs file verification
     - Parameter game: The game to check
     - Returns: `true` if verification is needed
     */
    static func isFileVerificationRequired(for game: Game) async throws -> Bool
}
