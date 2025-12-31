//
//  LocalGameManager.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 16/11/2025.
//

// Copyright © 2023-2026 vapidinfinity

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
                    await withTaskCancellationHandler {
                        await withCheckedContinuation { continuation in
                            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                                                              object: nil,
                                                                              queue: .main) { notification in
                                if let observedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                                   observedApplication == application {
                                    continuation.resume()
                                }
                            }
                        }
                    } onCancel: {
                        application.terminate()
                    }
                } else {
                    throw CocoaError(.serviceApplicationLaunchFailed)
                }
            case .windows:
                guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }
                let container = try Wine.getContainerObject(at: containerURL)

                var environment: [String: String] = .init()
                environment = try Wine.assembleEnvironmentVariables(forContainerAtURL: container.url)

                if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
                    NSApp.windows.first?.miniaturize(nil)
                }
                
                let process: Process = .init()
                process.arguments = [location.path] + game.launchArguments
                process.environment = environment
                Wine.transformProcess(process, containerURL: containerURL)
                
                try process.run()
                
                process.waitUntilExit()
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
            
            game.installationState = .uninstalled
            
            // remove the game from the library if present.
            // this is only necessary for non-storefront games.
            if GameDataStore.shared.library.contains(game) {
                GameDataStore.shared.library.remove(game)
            }
        }

        Game.operationManager.queueOperation(operation)
        return operation
    }
}
