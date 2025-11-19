//
//  EpicGamesGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

class EpicGamesGame: Game {
    override var computedVerticalImageURL: URL? { Legendary.getImageURL(of: self, type: .tall) }
    override var computedHorizontalImageURL: URL? { Legendary.getImageURL(of: self, type: .normal) }

    override var storefront: Storefront? { .epicGames }

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
        fatalError("init(from:) has not been implemented")
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
