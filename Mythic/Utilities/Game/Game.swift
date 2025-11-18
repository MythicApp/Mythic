//
//  Game.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

actor GameDataStore {
    // TODO: Migrate favouriteGames
    // TODO: Migrate localGamesLibrary
    // TODO: Migrate (id)_containerURL
    // TODO: Migrate (id)_launchArguments
    // TODO: Migrate (id)_containerURL
    // TODO: Acknowledge there is no need to migrate recentlyPlayed, due to lastLaunched

    var games: Set<Game> {
        get { Set((try? defaults.decodeAndGet([Game].self, forKey: "games")) ?? []) }
        set { _ = try? defaults.encodeAndSet(newValue, forKey: "games") }
    }

    func refresh() async throws {

    }
}

class Game: Codable, Identifiable {
    static let store: GameDataStore = .init()
    @MainActor static let operationManager: GameOperationManager = .shared

    let id: String
    let title: String
    let platform: Platform
    var storefront: Storefront? { nil } // override in subclass

    /*
     Store file location in underlying variable
     to be exposed by inheritors.
     i.e. `var location: URL { super._location! }`
     */
    // swiftlint:disable:next identifier_name
    var _location: URL?

    internal final var _verticalImageURL: URL? // for custom images
    final var verticalImageURL: URL? { _verticalImageURL ?? computedVerticalImageURL }
    internal var computedVerticalImageURL: URL? { nil } // override in subclass

    internal final var _horizontalImageURL: URL? // for custom images
    final var horizontalImageURL: URL? { _horizontalImageURL ?? computedHorizontalImageURL }
    internal var computedHorizontalImageURL: URL? { nil } // override in subclass

    // swiftlint:disable:next identifier_name
    internal final var _containerURL: URL?
    final var containerURL: URL? {
        get {
            guard case .windows = self.platform else { return nil }

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
         platform: Platform,
         location: URL?,
         containerURL: URL? = nil) {
        self.id = id
        self.title = title
        self.platform = platform
        self._location = location

        self._containerURL = containerURL ?? Wine.containerURLs.first
    }

    var isInstalled: Bool { false } // override in subclass

    final var isFallbackImageAvailable: Bool {
        switch platform {
        case .macOS:
            return false // FIXME: stub
        case .windows:
            return false // FIXME: stub
        }
    }

    // FIXME: better implementation, this is pulled from the old game management system
    final var isGameRunning: Bool {
        guard let location = _location else { return false }

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
        let operationQueue = Game.operationManager.queue
        let operation = operationQueue.first(where: { $0.game == self })
        return operation?.isExecuting == true
    }

    // MARK: Actions
    /// Launch the underlying game.
    @MainActor final func launch() async throws {
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
        try await _move(to: newLocation)
        _location = newLocation
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
    var description: String { "\(title) (\(platform), \(id))" }
}
