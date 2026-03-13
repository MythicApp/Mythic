//
//  SteamGameManager.swift
//  Mythic
//
//  Created on 12/3/2026.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import AppKit
import OSLog

extension SteamGameManager: StorefrontGameManager {
    @MainActor static func importGame(_ game: Game, platform: Game.Platform, at location: URL) async throws {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        try await importGame(castGame, in: location, platform: platform)
    }
    
    static func install(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Installing", game: castGame, reason: "Steam install integration is not implemented yet.")
    }
    
    static func update(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Updating", game: castGame, reason: "Steam update integration is not implemented yet.")
    }
    
    static func repair(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Verifying file integrity", game: castGame, reason: "Steam verification is not implemented yet.")
    }
    
    static func fetchUpdateAvailability(for game: Game) throws -> Bool {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Checking for updates", game: castGame, reason: "Steam update integration is not implemented yet.")
    }
    
    static func isFileVerificationRequired(for game: Game) throws -> Bool {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Checking file integrity requirements", game: castGame, reason: "Steam verification integration is not implemented yet.")
    }
    
    @MainActor static func launch(game: Game) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        return try await launch(game: castGame)
    }
    
    @MainActor static func move(game: Game, to newLocation: URL) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Moving", game: castGame, reason: "Steam library relocation is not implemented yet.")
    }
    
    @MainActor static func uninstall(game: Game, persistFiles: Bool) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let castGame = game as? SteamGame else { throw CocoaError(.coderInvalidValue) }
    
        throw unsupportedOperationError("Uninstalling", game: castGame, reason: "Steam uninstall integration is not implemented yet.")
    }
}

final class SteamGameManager {
    static var log: Logger { .custom(category: "SteamGameManager") }
    
    struct MissingWindowsSteamExecutableError: LocalizedError {
        let steamRootURL: URL
    
        var errorDescription: String? {
            "The selected Steam installation does not contain steam.exe at \(Steam.windowsExecutableURL(in: steamRootURL).prettyPath)."
        }
    }
    
    struct GameNotFoundInSteamLibraryError: LocalizedError {
        let gameID: String
        let steamRootURL: URL
    
        var errorDescription: String? {
            "Steam game \(gameID) was not found in \(steamRootURL.prettyPath)."
        }
    }
    
    private static func unsupportedOperationError(_ operation: String, game: SteamGame, reason: String) -> Game.UnsupportedOperationError {
        .init(operation: operation, game: game, reason: reason)
    }
    
    /// Steam launch has two truthful paths in Mythic today:
    /// 1. Native macOS Steam via the `steam://` protocol.
    /// 2. Existing Windows Steam installs inside a Wine container, launched through
    ///    that container's `steam.exe -applaunch <appid>` command line.
    static func canLaunch(game: SteamGame) -> Bool {
        guard case .installed = game.installationState,
              let source = game.installationSource else { return false }
    
        if let containerURL = source.containerURL {
            return Wine.containerURLs.contains(containerURL)
                && FileManager.default.fileExists(atPath: Steam.windowsExecutableURL(in: source.rootURL).path)
        }
    
        guard Steam.isClientInstalled else { return false }
        return (try? Steam.launchURL(forAppID: game.id, launchArguments: game.launchArguments)) != nil
    }
    
    @MainActor static func importGame(_ game: SteamGame,
                                      in steamRootURL: URL,
                                      platform: Game.Platform) async throws {
        guard case .windows = platform else {
            throw unsupportedOperationError("Importing", game: game, reason: "Mythic currently imports Steam games only from Windows Steam libraries.")
        }
    
        let normalizedSteamRootURL = steamRootURL.standardizedFileURL
        guard Steam.containsLibraryMetadata(in: normalizedSteamRootURL) else {
            throw Steam.Error.missingLibraryFoldersFile(normalizedSteamRootURL.appending(path: "steamapps").appending(path: "libraryfolders.vdf"))
        }
    
        guard let selectedContainerURL = game.installationSource?.containerURL else {
            throw unsupportedOperationError("Importing", game: game, reason: "Select the Wine container that owns this Windows Steam installation before importing.")
        }
    
        guard normalizedSteamRootURL.path.hasPrefix(selectedContainerURL.standardizedFileURL.path) else {
            throw unsupportedOperationError("Importing", game: game, reason: "The selected Steam root must live inside the chosen Wine container.")
        }
    
        let steamExecutableURL = Steam.windowsExecutableURL(in: normalizedSteamRootURL)
        guard FileManager.default.fileExists(atPath: steamExecutableURL.path) else {
            throw MissingWindowsSteamExecutableError(steamRootURL: normalizedSteamRootURL)
        }
    
        let importedGames = try Steam.getInstalledGames(in: normalizedSteamRootURL, containerURL: selectedContainerURL)
        guard let importedGame = importedGames.first(where: { $0.id == game.id }) else {
            throw GameNotFoundInSteamLibraryError(gameID: game.id, steamRootURL: normalizedSteamRootURL)
        }
    
        if let existing = GameDataStore.shared.library.first(where: { $0 == importedGame }) as? SteamGame {
            try existing.merge(with: importedGame, requiring: .identicalIgnoredKeys)
            existing.steamInstallationRootURL = importedGame.steamInstallationRootURL
            existing._containerURL = importedGame._containerURL
            GameDataStore.shared.library.update(with: existing)
        } else {
            GameDataStore.shared.library.update(with: importedGame)
        }
    }
    
    @discardableResult
    @MainActor static func launch(game: SteamGame) async throws -> GameOperation {
        guard case .installed = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }
    
        guard let source = game.installationSource else {
            throw unsupportedOperationError("Launching", game: game, reason: "This Steam game does not have a known Steam installation root.")
        }
    
        if let containerURL = source.containerURL {
            let steamExecutableURL = Steam.windowsExecutableURL(in: source.rootURL)
            guard FileManager.default.fileExists(atPath: steamExecutableURL.path) else {
                throw MissingWindowsSteamExecutableError(steamRootURL: source.rootURL)
            }
    
            let operation: GameOperation = .init(game: game, type: .launch) { _ in
                let process: Process = .init()
                process.arguments = [steamExecutableURL.path, "-silent", "-applaunch", game.id] + game.launchArguments
                Wine.transformProcess(process, containerURL: containerURL)
    
                try process.run()
    
                if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
                    await MainActor.run {
                        NSApp.windows.first?.miniaturize(nil)
                    }
                }
            }
    
            Game.operationManager.queueOperation(operation)
            return operation
        }
    
        guard Steam.isClientInstalled else { throw Steam.Error.clientNotInstalled }
        let launchURL = try Steam.launchURL(forAppID: game.id, launchArguments: game.launchArguments)
    
        let operation: GameOperation = .init(game: game, type: .launch) { _ in
            let didOpen = await MainActor.run { NSWorkspace.shared.open(launchURL) }
            guard didOpen else { throw Steam.Error.unableToOpenLaunchURL(launchURL) }
    
            if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
                await MainActor.run {
                    NSApp.windows.first?.miniaturize(nil)
                }
            }
        }
    
        Game.operationManager.queueOperation(operation)
        return operation
    }
}
