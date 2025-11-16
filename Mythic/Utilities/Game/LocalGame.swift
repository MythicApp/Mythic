//
//  LocalGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

class LocalGame: Game {
    // Local games MUST have .location, as marked in .init()
    var location: URL { super._location! }

    init(id: String = UUID().uuidString,
         title: String,
         platform: Platform,
         location: URL,
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
    
    // Local games are always present on disk.
    override var isInstalled: Bool { true }
    // Verification for local games isn't possible.
    override var needsVerification: Bool? { false }

    override func _launch() async throws {
        
    }
}
