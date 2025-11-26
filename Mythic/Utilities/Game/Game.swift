//
//  Game.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

var placeholderGame: Game { .init(id: "test", title: "Test", installationState: .installed(location: .temporaryDirectory, platform: .macOS)) }

@Observable @MainActor final class GameDataStore {
    static let shared: GameDataStore = .init()

    var library: Set<Game> {
        get {
            do {
                let anyGames = try defaults.decodeAndGet([AnyGame].self,
                                                         forKey: "games") ?? .init()
                return Set(anyGames.map({ $0.base }))
            } catch {
                Logger.app.error("""
                    Unable to decode game library.
                    This may result in unintended functionality.
                    \(error)
                    """)
            }

            return []
        }
        set {
            do {
                try defaults.encodeAndSet(newValue.map({ AnyGame($0) }),
                                          forKey: "games")
            } catch {
                Logger.app.error("""
                    Unable to encode game library.
                    This may result in unintended functionality.
                    \(error)
                    """)
            }
        }
    }

    var recent: Game? {
        guard !Game.store.library.allSatisfy({ $0.lastLaunched == nil }) else { return nil }

        return Game.store.library.max {
            $0.lastLaunched ?? .distantPast < $1.lastLaunched ?? .distantPast
        }
    }

    func refreshFromStorefronts() async throws {
        // legendary (epic games)
        let installables = try Legendary.getInstallableGames()
        let installed = try Legendary.getInstalledGames()

        // add installables that aren't installed
        for game in installables where !installed.contains(where: { $0 == game }) {
            library.update(with: game)
        }

        // installed: merge instead of overwrite
        for game in installed {
            if let existing = library.first(where: { $0 == game }) {
                game.merge(existing)
                library.update(with: game)
            } else {
                library.update(with: game)
            }
        }
    }

    private init() {}
}

@Observable class Game: Codable, Identifiable {
    @MainActor static let store: GameDataStore = .shared
    @MainActor static let operationManager: GameOperationManager = .shared

    let id: String
    var title: String
    var installationState: InstallationState

    var storefront: Storefront? { nil }

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

    var isUpdateAvailable: Bool? { nil } // override in subclass

    // swiftlint:disable:next identifier_name
    internal var _verticalImageURL: URL? // underlying storage for custom images
    var verticalImageURL: URL? { _verticalImageURL ?? computedVerticalImageURL }
    internal var computedVerticalImageURL: URL? { nil } // override in subclass — Auto-synthesized (default) image URL

    // swiftlint:disable:next identifier_name
    internal var _horizontalImageURL: URL? // underlying storage for custom images
    var horizontalImageURL: URL? { _horizontalImageURL ?? computedHorizontalImageURL }
    internal var computedHorizontalImageURL: URL? { nil } // override in subclass — Auto-synthesized (default) image URL

    var launchArguments: [String] = []
    final var isFavourited: Bool = false
    final var lastLaunched: Date?

    // override in subclass
    var supportedPlatforms: Set<Game.Platform>? { nil }

    init(id: String,
         title: String,
         installationState: InstallationState,
         containerURL: URL? = nil) {
        self.id = id
        self.title = title
        self.installationState = installationState

        self._containerURL = containerURL ?? Wine.containerURLs.first
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.installationState = try container.decode(InstallationState.self, forKey: .installationState)
        self._verticalImageURL = try container.decodeIfPresent(URL.self, forKey: ._verticalImageURL)
        self._horizontalImageURL = try container.decodeIfPresent(URL.self, forKey: ._horizontalImageURL)
        self._containerURL = try container.decodeIfPresent(URL.self, forKey: ._containerURL)
        self.launchArguments = try container.decode([String].self, forKey: .launchArguments)
        self.isFavourited = try container.decode(Bool.self, forKey: .isFavourited)
        self.lastLaunched = try container.decodeIfPresent(Date.self, forKey: .lastLaunched)
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

    // MARK: Actions
    final func checkIfOperating() async -> Bool {
        return await (Game.operationManager.queue.first(where: { $0.game == self && $0.isExecuting }) != nil)
    }

    final func checkIfGameIsRunning() -> Bool {
        guard case .installed(let location, let platform) = installationState else { return false }
        return _checkIfGameIsRunning(location: location, platform: platform)
    }

    /// Launch the underlying game.
    @MainActor final func launch() async throws {
        guard case .installed = installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        lastLaunched = .now
        try await _launch()
    }

    @MainActor final func update() async throws {
        guard case .installed = installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard isUpdateAvailable == true else { return }

        try await _update()
    }

    /// Move the underlying game to a specified `URL`.
    @MainActor final func move(to newLocation: URL) async throws {
        guard case .installed(let currentLocation, let platform) = installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        try await _move(from: currentLocation,
                        to: newLocation,
                        platform: platform)
    }

    /// Verify the file integrity of the game (if it's installed)
    final func verifyInstallation() async throws {
        guard case .installed = installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        try await _verifyInstallation()
    }

    // MARK: Overrideable Actions

    // override in subclass
    func _checkIfGameIsRunning(location: URL, platform: Platform) -> Bool {
        // swiftlint:disable:previous identifier_name
        Logger.app.warning("""
            _checkIfGameIsRunning() called on \(self).
            This means that the subclass calling this method does not have an override,
            Or that this method was called from the `Game` base class.
            This is not intended behaviour, and thus, a basic fallback will be used.
            """)

        if case .macOS = platform {
            return workspace.runningApplications.contains(where: { $0.bundleURL == location })
        }

        return false
    }

    // override in subclass
    @MainActor internal func _launch() async throws {
        // swiftlint:disable:previous identifier_name
        fatalError("Subclasses must implement _launch()")
    }

    // override in subclass
    @MainActor internal func _update() async throws {
        // swiftlint:disable:previous identifier_name
        fatalError("Subclasses must implement _update()")
    }

    // override in subclass
    @MainActor internal func _move(from currentLocation: URL, // swiftlint:disable:this identifier_name
                                   to newLocation: URL,
                                   platform: Platform) async throws {
        fatalError("Subclasses must implement _move(to:)")
    }

    // override in subclass
    internal func _verifyInstallation() async throws {
        // swiftlint:disable:previous identifier_name
        assertionFailure("Subclasses should implement _verifyInstallation()")
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
    var description: String { "\"\(title)\"" }
    var debugDescription: String { "\(description) (\(installationState), \(id))" }
}

// MARK: - Codable Polymorphism Support
extension Game {
    enum CodingKeys: String, CodingKey {
        case id,
             title,
             installationState
        case storefront
        // swiftlint:disable identifier_name
        case _verticalImageURL,
             _horizontalImageURL
        case _containerURL
        // swiftlint:enable identifier_name
        case launchArguments,
             isFavourited,
             lastLaunched
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(installationState, forKey: .installationState)
        try container.encodeIfPresent(storefront, forKey: .storefront)
        try container.encodeIfPresent(_verticalImageURL, forKey: ._verticalImageURL)
        try container.encodeIfPresent(_horizontalImageURL, forKey: ._horizontalImageURL)
        try container.encodeIfPresent(_containerURL, forKey: ._containerURL)
        try container.encode(launchArguments, forKey: .launchArguments)
        try container.encode(isFavourited, forKey: .isFavourited)
        try container.encodeIfPresent(lastLaunched, forKey: .lastLaunched)
    }
}

extension Game: Mergeable {
    func merge(_ other: Game) {
        _verticalImageURL = self._verticalImageURL ?? other._verticalImageURL
        _horizontalImageURL = self._horizontalImageURL ?? other._horizontalImageURL
        _containerURL = self._containerURL ?? other._containerURL

        launchArguments = .init(Set(self.launchArguments + other.launchArguments))

        if self.lastLaunched != nil || other.lastLaunched != nil {
            lastLaunched = max(self.lastLaunched ?? .distantPast,
                               other.lastLaunched ?? .distantPast)
        }
    }
}

struct AnyGame: Codable {
    let base: Game

    init(_ base: Game) {
        self.base = base
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Game.CodingKeys.self)
        let storefront = try container.decodeIfPresent(Game.Storefront.self, forKey: .storefront)

        self.base = try {
            switch storefront {
            case .epicGames:    try EpicGamesGame(from: decoder)
            case .local:        try LocalGame(from: decoder)
            case nil:           try Game(from: decoder)
            }
        }()
    }

    func encode(to encoder: Encoder) throws {
        try base.encode(to: encoder)
    }
}
