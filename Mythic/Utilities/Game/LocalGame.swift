//
//  LocalGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog

class LocalGame: Game {
    override var storefront: Storefront? { .local }

    override init(id: String = UUID().uuidString,
                  title: String,
                  installationState: InstallationState,
                  containerURL: URL? = nil) {
        if case .uninstalled = installationState {
            Logger.app.debug("""
                LocalGame initialised as uninstalled — this is not recommended.
                This instance must not be persisted unless installationState is set to installed.
                """)
        }
        
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
    
    override func _update() async throws {
        assertionFailure("Attempted to update a LocalGame, which is not possible.")
    }
    
    override func _move(from currentLocation: URL,
                        to newLocation: URL) async throws {
        try await LocalGameManager.move(game: self, to: newLocation)
    }
    
    override func _verifyInstallation() async throws {
        assertionFailure("Attempted to verify the installation of a LocalGame, which is not possible.")
    }
}
