//
//  SteamGameManager.swift
//  Mythic
//

import AppKit
import Foundation
import OSLog

extension SteamGameManager: StorefrontGameManager {
    @MainActor static func importGame(_ game: Game, platform: Game.Platform, at location: URL) async throws {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        try await importGame(steamGame, platform: platform, at: location)
    }

    static func install(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        let platform = try operationContext(for: steamGame).platform
        return try await install(game: steamGame, platform: platform, qualityOfService: qualityOfService)
    }

    static func update(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try await update(game: steamGame, qualityOfService: qualityOfService)
    }

    static func repair(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try await repair(game: steamGame, qualityOfService: qualityOfService)
    }

    static func fetchUpdateAvailability(for game: Game) throws -> Bool {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try fetchUpdateAvailability(for: steamGame)
    }

    static func isFileVerificationRequired(for game: Game) throws -> Bool {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try isFileVerificationRequired(for: steamGame)
    }

    @MainActor static func launch(game: Game) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try await Task(operation: { try await launch(game: steamGame) }).value
    }

    @MainActor static func move(game: Game, to newLocation: URL) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try await move(game: steamGame, to: newLocation)
    }

    @MainActor static func uninstall(game: Game, persistFiles: Bool) async throws -> GameOperation {
        guard case .steam = game.storefront,
              let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return try await uninstall(game: steamGame, persistFiles: persistFiles)
    }
}

class SteamGameManager {
    static var log: Logger { .custom(category: "SteamGameManager") }

    struct UnsupportedOperationError: LocalizedError {
        var errorDescription: String? {
            String(localized: "Steam manages this; use the Steam client.")
        }
    }

    @discardableResult
    @MainActor static func launch(game: SteamGame) async throws -> GameOperation {
        let context = try operationContext(for: game)
        let launchArguments = game.launchArguments

        if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
            NSApp.windows.first?.miniaturize(nil)
        }

        let operation = GameOperation(game: game, type: .launch) { _ in
            try await SteamClient.perform(
                action: "rungameid",
                appID: context.appID,
                platform: context.platform,
                containerURL: context.containerURL,
                extraArguments: launchArguments
            )
        }
        Game.operationManager.queueOperation(operation)
        return operation
    }

    @discardableResult
    static func install(game: SteamGame,
                        platform: Game.Platform,
                        containerURL: URL? = nil,
                        qualityOfService: QualityOfService) async throws -> GameOperation {
        let context = try operationContext(for: game, requestedPlatform: platform, requestedContainerURL: containerURL)
        return await queueOperation(game: game, type: .install, action: "install", context: context)
    }

    @discardableResult
    static func update(game: SteamGame, qualityOfService: QualityOfService) async throws -> GameOperation {
        let context = try operationContext(for: game)
        return await queueOperation(game: game, type: .update, action: "install", context: context)
    }

    @discardableResult
    static func repair(game: SteamGame, qualityOfService: QualityOfService) async throws -> GameOperation {
        let context = try operationContext(for: game)
        return await queueOperation(game: game, type: .repair, action: "validate", context: context)
    }

    @discardableResult
    @MainActor static func uninstall(game: SteamGame, persistFiles: Bool) async throws -> GameOperation {
        _ = persistFiles
        let context = try operationContext(for: game)
        let operation = makeOperation(game: game, type: .uninstall, action: "uninstall", context: context)
        Game.operationManager.queueOperation(operation)
        return operation
    }

    @MainActor static func move(game: SteamGame, to newLocation: URL) async throws -> GameOperation {
        _ = game
        _ = newLocation
        throw UnsupportedOperationError()
    }

    static func fetchUpdateAvailability(for game: SteamGame) throws -> Bool {
        guard let appID = game.appID else { throw SteamClient.InvalidAppIDError() }
        return SteamClient.installedApp(appID: appID)?.isUpdateRequired ?? false
    }

    static func isFileVerificationRequired(for game: SteamGame) throws -> Bool {
        _ = game
        return false
    }

    @MainActor static func importGame(_ game: SteamGame,
                                      platform: Game.Platform,
                                      at location: URL) async throws {
        _ = game
        _ = platform
        _ = location
        throw UnsupportedOperationError()
    }

    private struct OperationContext {
        let appID: String
        let platform: Game.Platform
        let containerURL: URL?
    }

    private static func operationContext(for game: SteamGame,
                                         requestedPlatform: Game.Platform? = nil,
                                         requestedContainerURL: URL? = nil) throws -> OperationContext {
        guard let appID = game.appID,
              SteamClient.isValidAppID(appID) else {
            throw SteamClient.InvalidAppIDError()
        }

        let installedApp = SteamClient.installedApp(appID: appID)
        let gamePlatform: Game.Platform?
        if case .installed(_, let platform) = game.installationState {
            gamePlatform = platform
        } else {
            gamePlatform = nil
        }
        let platform = requestedPlatform
            ?? installedApp?.location.platform
            ?? gamePlatform
            ?? (SteamClient.isNativeClientInstalled ? .macOS : .windows)
        return OperationContext(
            appID: appID,
            platform: platform,
            containerURL: requestedContainerURL ?? installedApp?.location.containerURL ?? game.containerURL
        )
    }

    private static func makeOperation(game: SteamGame,
                                      type: GameOperation.ActiveOperationType,
                                      action: String,
                                      context: OperationContext) -> GameOperation {
        GameOperation(game: game, type: type) { _ in
            try await SteamClient.perform(
                action: action,
                appID: context.appID,
                platform: context.platform,
                containerURL: context.containerURL
            )
        }
    }

    private static func queueOperation(game: SteamGame,
                                       type: GameOperation.ActiveOperationType,
                                       action: String,
                                       context: OperationContext) async -> GameOperation {
        let operation = makeOperation(game: game, type: type, action: action, context: context)
        await Game.operationManager.queueOperation(operation)
        return operation
    }
}
