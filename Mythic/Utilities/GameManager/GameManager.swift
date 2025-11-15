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
    static func launch(game: Game) async throws

    /**
     Move a game to a new location
     - Parameters:
        - game: The game to move
        - location: The target file location of the move operation.
     */
    static func move(game: Game, to location: URL) async throws

    /**
     Uninstall a game
     - Parameters:
        - game: The game to uninstall.
        - persistFiles: Whether to delete the game files from disk.
     */
    static func uninstall(game: Game, persistFiles: Bool) async throws
}

/// Protocol defining additional game manager functionality for storefronts (Epic, Steam, etc.)
protocol StorefrontGameManager: GameManager {
    /**
     Install, update, or repair a game
     - Parameters:
        - arguments: Installation configuration and parameters
        - priority: Whether this installation should be prioritized
        - Throws: Various installation errors
     */
    static func install(arguments: GameOperation.InstallArguments, priority: Bool) async throws

    /// Check if a game update is available.
    static func fetchUpdateAvailability(for game: Game) -> Bool

    /**
     Check if a game needs file verification
     - Parameter game: The game to check
     - Returns: `true` if verification is needed
     */
    static func needsVerification(for game: Game) -> Bool

    /**
     Get the installation path for a game
     - Parameter game: The game to get the path for
     - Returns: The installation path as a string, or nil if not found
     */
    static func getGamePath(for game: Game) throws -> URL

    /// Get the platform a game is installed for.
    static func getInstalledGamePlatform(for game: Game) -> Game.Platform
}
