//
//  Game.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

// TODO: migrate favouriteGames
// TODO: update LegacyGameOperation, fix implementation to be less convoluted

actor GameDataStore {
    var games: [Game] {
        get { (try? defaults.decodeAndGet([Game].self, forKey: "games")) ?? [] }
        set { _ = try? defaults.encodeAndSet(newValue, forKey: "games") }
    }
}

class Game: Codable, Identifiable {
    static let store: GameDataStore = .init()

    let id: String
    let title: String
    let platform: Platform
    var storefront: Storefront? { nil } // override in subclass

    /*
     Store file location in underlying variable
     to be exposed by inheritors.
     */
    // swiftlint:disable:next identifier_name
    var _location: URL?

    var verticalImageURL: URL?
    var horizontalImageURL: URL?

    var containerURL: URL?

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

        self.containerURL = containerURL ?? Wine.containerURLs.first
    }

    var isInstalled: Bool { false }         // override in subclass
    var needsVerification: Bool? { nil }    // override in subclass

    final var isFallbackImageAvailable: Bool {
        switch platform {
        case .macOS:
            return false // FIXME: stub
        case .windows:
            return false // FIXME: stub
        }
    }

    /* FIXME: TODO: uncomment
    @MainActor var isInstalling: Bool {
        LegacyGameOperation.shared.current?.game == self
    }
    @MainActor var isQueuedForInstalling: Bool {
        LegacyGameOperation.shared.queue.contains(where: { $0.game == self })
    }
    @MainActor var isLaunching: Bool {
        LegacyGameOperation.shared.launching == self
    }
     */

    // MARK: Actions
    /// Launch the underlying game.
    @MainActor final func launch() async throws {
        lastLaunched = .now
        try await _launch()
    }

    @MainActor internal func _launch() async throws {
        // swiftlint:disable:previous identifier_name
        fatalError("Subclasses must implement _launch()")
    }

    /// Launch the underlying game.
    @MainActor final func move(to newLocation: URL) async throws {
        try await _move(to: newLocation)
        _location = newLocation
    }

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
