//
//  EpicGamesGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

class EpicGamesGame: Game {
    var location: URL? { super._location }

    override var computedVerticalImageURL: URL? { Legendary.getImageURL(of: self, type: .tall) }
    override var computedHorizontalImageURL: URL? { Legendary.getImageURL(of: self, type: .normal) }

    override var storefront: Storefront? { .epicGames }

    override init(id: String,
                  title: String,
                  platform: Game.Platform,
                  location: URL?,
                  containerURL: URL? = nil) {
        super.init(id: id,
                   title: title,
                   platform: platform,
                   location: location,
                   containerURL: containerURL)
    }

    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    override var isInstalled: Bool {
        guard let installedGames = try? Legendary.getInstalledGames() else {
            return false
        }

        return installedGames.contains(where: { $0.id == id })
    }
    
    var isUpdateAvailable: Bool? { try? Legendary.fetchUpdateAvailability(for: self) }
    var isFileVerificationRequired: Bool? { try? Legendary.isFileVerificationRequired(for: self) }

    override func _launch() async throws {
        try await EpicGamesGameManager.launch(game: self)
    }
}

extension EpicGamesGame {
    struct VerificationRequiredError: LocalizedError {
        var errorDescription: String? { String(localized: "This game's data integrity must be verified.") }
    }
}
