//
//  LocalGameManager.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 16/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import AppKit
import OSLog

extension LocalGameManager: GameManager {
    @MainActor static func launch(game: Game) async throws -> GameOperation {
        guard case .local = game.storefront,
              let castGame = game as? LocalGame else { throw CocoaError(.coderInvalidValue) }

        return try await launch(game: castGame)
    }

    @MainActor static func move(game: Game,
                                to newLocation: URL) async throws -> GameOperation {
        guard case .local = game.storefront,
              let castGame = game as? LocalGame else { throw CocoaError(.coderInvalidValue) }

        return try await move(game: castGame, to: newLocation)
    }

    @MainActor static func uninstall(game: Game,
                                     persistFiles: Bool) async throws -> GameOperation {
        guard case .local = game.storefront,
              let castGame = game as? LocalGame else { throw CocoaError(.coderInvalidValue) }

        return try await uninstall(game: castGame, persistFiles: persistFiles)
    }
}

class LocalGameManager {
    static var log: Logger { .custom(category: "LocalGameManager") }

    @discardableResult
    @MainActor static func launch(game: LocalGame) async throws -> GameOperation {
        guard case .installed(let location, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        defer {
            if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
        }

        let operation: GameOperation = .init(game: game, type: .launch) { _ in
            switch platform {
            case .macOS:
                let configuration: NSWorkspace.OpenConfiguration = .init()
                configuration.arguments = game.launchArguments

                if (try? location.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .bundle) == true {
                    let application = try await NSWorkspace.shared.openApplication(at: location, configuration: configuration)
                    
                    // await application closure
                    /* FIXME: nonfunctional, why????
                    await withCheckedContinuation { continuation in
                        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                                                          object: nil,
                                                                          queue: .main) { notification in
                            if let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                               terminatedApp.processIdentifier == application.processIdentifier {
                                continuation.resume()
                            }
                        }
                    }
                     */
                } else {
                    throw CocoaError(.serviceApplicationLaunchFailed)
                }
            case .windows:
                guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }
                let container = try Wine.getContainerObject(url: containerURL)

                let environmentVariables: [String: String] = .init() /* FIXME: stub */ /* try Wine.assembleEnvironmentVariables(forGame: game) */

                if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
                    NSApp.windows.first?.miniaturize(nil)
                }

                try await Wine.execute(arguments: [location.path] + game.launchArguments,
                                           containerURL: container.url,
                                           environment: environmentVariables)
            }
        }

        Game.operationManager.queueOperation(operation)
        return operation
    }

    @discardableResult
    @MainActor static func move(game: LocalGame,
                                to newLocation: URL) async throws -> GameOperation {
        guard case .installed(let currentLocation, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let operation: GameOperation = .init(game: game, type: .uninstall) {  _ in
            try FileManager.default.moveItem(at: currentLocation, to: newLocation)
            game.installationState = .installed(location: newLocation, platform: platform)
        }
        return operation
    }

    @discardableResult
    @MainActor static func uninstall(game: LocalGame,
                                     persistFiles: Bool) async throws -> GameOperation {
        guard case .installed(let location, _) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let operation: GameOperation = .init(game: game, type: .uninstall) {  _ in
            if !persistFiles {
                try FileManager.default.removeItem(at: location)
            }

            // FIXME: not ideal, initialiser states no installationstate should be .uninstalled
            // FIXME: ideally, destroy the game object somehow
            game.installationState = .uninstalled
        }

        Game.operationManager.queueOperation(operation)
        return operation
    }
}
