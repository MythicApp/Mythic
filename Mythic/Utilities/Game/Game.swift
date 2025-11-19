//
//  Game.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

actor GameDataStore {
    // TODO: Migrate favouriteGames
    // TODO: Migrate localGamesLibrary
    // TODO: Migrate (id)_containerURL
    // TODO: Migrate (id)_launchArguments
    // TODO: Migrate (id)_containerURL
    // TODO: Acknowledge there is no need to migrate recentlyPlayed, due to lastLaunched

    var games: Set<Game> {
        get { Set((try? defaults.decodeAndGet([Game].self, forKey: "games")) ?? []) }
        set {
            do {
                try defaults.encodeAndSet(newValue, forKey: "games")
            } catch {
                Logger.app.error("""
                    Unable to encode game library.
                    This may result in unintended functionality.
                    \(error.localizedDescription)
                    """)
            }
        }
    }

    func refreshFromStorefronts() async throws {
        let legendaryInstallables = try Legendary.getInstallableGames()
        for installable in legendaryInstallables {
            games.insert(installable)
        }
    }
}

class Game: Codable, Identifiable {
    static let store: GameDataStore = .init()
    @MainActor static let operationManager: GameOperationManager = .shared

    let id: String
    let title: String
    var installationState: InstallationState
    var storefront: Storefront? { nil } // override in subclass

    internal final var _verticalImageURL: URL? // underlying storage for custom images
    final var verticalImageURL: URL? { _verticalImageURL ?? computedVerticalImageURL }
    internal var computedVerticalImageURL: URL? { nil } // override in subclass

    internal final var _horizontalImageURL: URL? // underlying storage for custom images
    final var horizontalImageURL: URL? { _horizontalImageURL ?? computedHorizontalImageURL }
    internal var computedHorizontalImageURL: URL? { nil } // override in subclass

    // swiftlint:disable:next identifier_name
    internal final var _containerURL: URL?
    final var containerURL: URL? {
        get {
            if Wine.containerURLs.first(where: { $0 == _containerURL }) == nil
                || _containerURL == nil {
                _containerURL = Wine.containerURLs.first
            }

            return _containerURL
        }
        set { _containerURL = newValue }
    }

    var launchArguments: [String] = []
    var isFavourited: Bool = false
    var lastLaunched: Date?

    init(id: String,
         title: String,
         installationState: InstallationState,
         containerURL: URL? = nil) {
        self.id = id
        self.title = title
        self.installationState = installationState

        self._containerURL = containerURL ?? Wine.containerURLs.first
    }

    final var isFallbackImageAvailable: Bool {
        guard case .installed(_, let platform) = installationState else {
            return false
        }

        switch platform {
        case .macOS:    return true
        case .windows:  return false
        }
    }

    var supportedPlatforms: [Game.Platform] = .init()

    // FIXME: better implementation, this is pulled from the old game management system
    final var isGameRunning: Bool {
        guard case .installed(let location, let platform) = installationState else { return false }

        switch platform {
        case .macOS:
            return workspace.runningApplications.contains(where: { $0.bundleURL == location })
        case .windows:
            // FIXME: hacky but functional
            let result = try? Process.execute(executableURL: .init(filePath: "/bin/bash"),
                arguments: ["-c", "ps aux | grep -i '\(location.path)' | grep -v grep"])

            return (result?.standardOutput.isEmpty == false)
        }
    }

    @MainActor final func isOperating() async -> Bool {
        return (Game.operationManager.queue.first(where: { $0.game == self && $0.isExecuting }) != nil)
    }

    // MARK: Actions
    /// Launch the underlying game.
    @MainActor final func launch() async throws {
        guard case .installed(let location, let platform) = installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        lastLaunched = .now
        try await _launch()
    }

    // override in subclass
    @MainActor internal func _launch() async throws {
        // swiftlint:disable:previous identifier_name
        fatalError("Subclasses must implement _launch()")
    }

    /// Move the underlying game to a specified `URL`.
    @MainActor final func move(to newLocation: URL) async throws {
        guard case .installed(let location, let platform) = installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        try await _move(to: newLocation)

        installationState = .installed(location: newLocation, platform: platform)
    }

    // override in subclass
    @MainActor internal func _move(to newLocation: URL) async throws {
        // swiftlint:disable:previous identifier_name
        fatalError("Subclasses must implement _move(to:)")
    }
}

extension Game: Equatable {
    public static func == (lhs: Game, rhs: Game) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Game: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Game: CustomStringConvertible {
    var description: String { "\(title) (\(installationState), \(id))" }
}
