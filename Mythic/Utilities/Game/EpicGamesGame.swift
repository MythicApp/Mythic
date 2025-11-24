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

    override var computedVerticalImageURL: URL? { Legendary.getImageURL(of: self, type: .tall) }
    override var computedHorizontalImageURL: URL? { Legendary.getImageURL(of: self, type: .normal) }

    private(set) var installationDataLastRefreshed: Date?
    // swiftlint:disable:next identifier_name
    var _cachedInstallationData: Legendary.InstalledGame? {
        didSet { installationDataLastRefreshed = .now }
    }
    private(set) var metadataLastRefreshed: Date?
    // swiftlint:disable:next identifier_name
    var _cachedMetadata: Legendary.GameMetadata? {
        didSet { metadataLastRefreshed = .now }
    }

    override init(id: String,
                  title: String,
                  installationState: InstallationState,
                  containerURL: URL? = nil) {
        super.init(id: id,
                   title: title,
                   installationState: installationState,
                   containerURL: containerURL)
    }

    init(id: String,
         title: String,
         installationState: InstallationState,
         containerURL: URL? = nil,
         initialMetadata: Legendary.GameMetadata,
         initialInstallationData: Legendary.InstalledGame? = nil) {
        _cachedMetadata = initialMetadata

        if case .installed = installationState, initialInstallationData == nil {
            preconditionFailure("EpicGamesGames must have initialInstallationData when initialised as .installed")
        }
        _cachedInstallationData = initialInstallationData

        super.init(id: id,
                   title: title,
                   installationState: installationState,
                   containerURL: containerURL)
    }

    required init(from decoder: any Decoder) throws {
        // super.init(from:) handles all decoding including subclass routing
        // say 'thank you, super.init❤️'
        try super.init(from: decoder)
    }

    override var isUpdateAvailable: Bool? { try? Legendary.fetchUpdateAvailability(for: self) }
    var isFileVerificationRequired: Bool? { try? Legendary.isFileVerificationRequired(for: self) }

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
