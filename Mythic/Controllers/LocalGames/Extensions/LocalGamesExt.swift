//
//  LocalGamesExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/1/2024.
//

import Foundation

extension LocalGames {
    struct Game: Codable {
        var title: String
        var imageURL: URL? = nil
        var platform: GamePlatform
        var path: String
    }
}
