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
    @MainActor static func launch(game: Game) async throws {
        guard case .local = game.storefront,
              let castGame = game as? LocalGame else { return }

        try await launch(game: castGame)
    }

    @MainActor static func move(game: Game,
                                to newLocation: URL) async throws {
        guard case .local = game.storefront,
              let castGame = game as? LocalGame else { return }

        try await move(game: castGame, to: newLocation)
    }

    @MainActor static func uninstall(game: Game,
                                     persistFiles: Bool) async throws {
        guard case .local = game.storefront,
              let castGame = game as? LocalGame else { return }

        try await uninstall(game: castGame, persistFiles: persistFiles)
    }
}

class LocalGameManager {
    static var log: Logger { .custom(category: "LocalGameManager") }

    @MainActor static func launch(game: LocalGame) async throws {
        guard case .installed(let location, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let launchArguments = game.launchArguments
        let containerURL = game.containerURL

        defer {
            if defaults.bool(forKey: "minimiseOnGameLaunch") {
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
        }

        let operation: GameOperation = .init(game: game, type: .launching) { _ in
            switch platform {
            case .macOS:
                let configuration: NSWorkspace.OpenConfiguration = .init()
                configuration.arguments = launchArguments

                if let contentType = try location.resourceValues(forKeys: [.contentTypeKey]).contentType,
                   contentType.conforms(to: .bundle) {
                    try await workspace.open(location, configuration: configuration)
                } else {
                    throw CocoaError(.serviceApplicationLaunchFailed)
                }
            case .windows:
                guard let containerURL = containerURL else { throw Wine.Container.DoesNotExistError() }
                let container = try Wine.getContainerObject(url: containerURL)

                let environmentVariables: [String: String] = .init() /* FIXME: stub */ /* try Wine.assembleEnvironmentVariables(forGame: game) */

                if defaults.bool(forKey: "minimiseOnGameLaunch") {
                    await NSApp.windows.first?.miniaturize(nil)
                }

                try await Wine.execute(arguments: [location.path] + launchArguments,
                                           containerURL: container.url,
                                           environment: environmentVariables)
            }
        }

        Game.operationManager.queueOperation(operation)
    }

    @MainActor static func move(game: LocalGame,
                                to newLocation: URL) async throws {
        guard case .installed(let currentLocation, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        try files.moveItem(at: currentLocation, to: newLocation)

        game.installationState = .installed(location: newLocation, platform: platform)
    }

    @MainActor static func uninstall(game: LocalGame,
                                     persistFiles: Bool) async throws {
        guard case .installed(let location, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        try files.removeItem(at: location)

        // FIXME: not ideal, initialiser states no installationstate should be .uninstalled
        game.installationState = .uninstalled
    }
}
