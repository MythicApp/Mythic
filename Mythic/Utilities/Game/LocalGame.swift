//
//  LocalGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

class LocalGame: Game {
    override var storefront: Storefront? { .local }

    override init(id: String = UUID().uuidString,
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

    override func _launch() async throws {
        try await LocalGameManager.launch(game: self)
    }
}
