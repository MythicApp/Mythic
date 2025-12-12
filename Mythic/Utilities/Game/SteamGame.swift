//
//  SteamGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

// haha you thought

import Foundation

@available(*, deprecated, message: "Soon...")
class SteamGame: Game {
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
}
