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

    override var storefront: Storefront? { .epicGames }

    init(id: String,
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
    
    override var isInstalled: Bool {
        guard let installedGames = try? Legendary.getInstalledGames() else {
            return false
        }

        return installedGames.contains(where: { $0.id == id })
    }
    
    var needsUpdate: Bool? {
        // TODO: FIXME: return try? Legendary.needsUpdate(game: self)
        return true // FIXME: stub
    }

    override var needsVerification: Bool? {
        // TODO: FIXME: return try? Legendary.needsVerification(game: self)
        return true // FIXME: stub
    }

    override func _launch() async throws {
        // TODO: FIXME: try await Legendary.launch(game: self)
    }
}
