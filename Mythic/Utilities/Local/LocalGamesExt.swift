//
//  LocalGamesExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/1/2024.
//

import Foundation

extension LocalGames {
    @available(*, deprecated, message: "Replaced by Mythic.Game")
    struct Game: Codable {
        var title: String
        var imageURL: URL?
        var platform: Mythic.Game.Platform
        var path: String
    }
}
