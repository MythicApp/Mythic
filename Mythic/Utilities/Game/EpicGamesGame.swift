//
//  EpicGamesGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

class EpicGamesGame: Game {
    override var storefront: Storefront? { .epicGames }

    override var computedVerticalImageURL: URL? { Legendary.getImageURL(gameID: self.id, type: .tall) }
    override var computedHorizontalImageURL: URL? { Legendary.getImageURL(gameID: self.id, type: .normal) }

    private(set) var legendaryInstallationDataLastRefreshed: Date?
    internal var _cachedLegendaryInstallationData: Legendary.InstalledGame? {
        // swiftlint:disable:previous identifier_name
        didSet { legendaryInstallationDataLastRefreshed = .now }
    }
    var legendaryInstallationData: Legendary.InstalledGame? {
        get {
            guard case .installed = installationState else { return nil }
            let lastRefreshed: Date = legendaryInstallationDataLastRefreshed ?? .distantPast
            if Calendar.current.date(byAdding: .hour, value: -12, to: .now)! > lastRefreshed {
                self._cachedLegendaryInstallationData = try? Legendary.getGameInstallationData(gameID: self.id)
            }

            return _cachedLegendaryInstallationData
        }
        set {
            _cachedLegendaryInstallationData = newValue
        }
    }

    private(set) var legendaryMetadataLastRefreshed: Date?
    internal var _cachedLegendaryMetadata: Legendary.GameMetadata? {
        // swiftlint:disable:previous identifier_name
        didSet { legendaryMetadataLastRefreshed = .now }
    }
    var legendaryMetadata: Legendary.GameMetadata? {
        get {
            let lastRefreshed: Date = legendaryInstallationDataLastRefreshed ?? .distantPast
            if Calendar.current.date(byAdding: .hour, value: -12, to: .now)! > lastRefreshed {
                // FIXME: not ideal, will hold caller
                self._cachedLegendaryMetadata = try? Legendary.getGameMetadata(gameID: self.id)
            }
            return _cachedLegendaryMetadata
        }
        set {
            _cachedLegendaryMetadata = newValue
        }
    }

    override init(id: String,
                  title: String,
                  installationState: InstallationState,
                  containerURL: URL? = nil) {
        super.init(id: id,
                   title: title,
                   installationState: installationState,
                   containerURL: containerURL)

        self._cachedLegendaryInstallationData = try? Legendary.getGameInstallationData(gameID: self.id)
        self._cachedLegendaryMetadata = try? Legendary.getGameMetadata(gameID: self.id)
    }

    required init(from decoder: any Decoder) throws {
        // super.init(from:) handles all decoding including subclass routing
        // say 'thank you, super.init❤️'
        try super.init(from: decoder)
    }

    override var isUpdateAvailable: Bool? { try? Legendary.fetchUpdateAvailability(gameID: self.id) }
    var isFileVerificationRequired: Bool? { try? Legendary.isFileVerificationRequired(gameID: self.id) }

    override func _checkIfGameIsRunning(location: URL, platform: Platform) -> Bool {
        switch platform {
        case .macOS:
            return workspace.runningApplications.contains(where: { $0.bundleURL == location })
        case .windows:
            return false // FIXME: stub
            /* FIXME: beefster code, tired, will refactor
            if let containerURL = self.containerURL,
               let _cachedInstallationData = _cachedInstallationData,
               let lastRefreshed = installationDataLastRefreshed,
               // last refreshed less than a week ago?
               lastRefreshed > Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
               let tasklist = try? await Wine.tasklist(containerURL: containerURL) {
                return tasklist.contains(where: { $0.name == _cachedInstallationData.executable })
            }
             */
        }
    }

    override func _launch() async throws {
        Task {
            try await EpicGamesGameManager.launch(game: self)
        }
    }

    override func _update() async throws {
        Task {
            try await EpicGamesGameManager.update(game: self, qualityOfService: .default)
        }
    }

    override func _move(to newLocation: URL) async throws {
        Task {
            try await EpicGamesGameManager.move(game: self, to: newLocation)
        }
    }

    override func _verifyInstallation() async throws {
        try await EpicGamesGameManager.repair(game: self, qualityOfService: .default)
    }
}

extension EpicGamesGame {
    struct VerificationRequiredError: LocalizedError {
        var errorDescription: String? { String(localized: "This game's data integrity must be verified.") }
    }
}
