//
//  EpicGamesGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import AppKit

class EpicGamesGame: Game {
    override var storefront: Storefront? { .epicGames }

    override var computedVerticalImageURL: URL? { Legendary.getImageURL(gameID: self.id, type: .tall) }
    override var computedHorizontalImageURL: URL? { Legendary.getImageURL(gameID: self.id, type: .normal) }

    override func getSupportedPlatforms() -> Set<Game.Platform>? {
        let metadata = try? Legendary.getGameMetadata(gameID: self.id)
        let latestGameRelease = metadata?.storeMetadata.releaseInfo
            .max(by: { $0.dateAdded ?? .distantPast < $1.dateAdded ?? .distantPast })

        return .init(latestGameRelease?.platform ?? [])
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
            return NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL == location })
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
    
    nonisolated override func _launch() async throws {
        try await EpicGamesGameManager.launch(game: self)
    }
    
    nonisolated override func _update() async throws {
        try await EpicGamesGameManager.update(game: self, qualityOfService: .default)
    }
    
    nonisolated override func _move(from currentLocation: URL,
                                    to newLocation: URL) async throws {
        try await EpicGamesGameManager.move(game: self, to: newLocation)
    }
    
    nonisolated override func _verifyInstallation() async throws {
        try await EpicGamesGameManager.repair(game: self, qualityOfService: .default)
    }
}

extension EpicGamesGame {
    struct VerificationRequiredError: LocalizedError {
        var errorDescription: String? { String(localized: "This game's data integrity must be verified.") }
    }
}
