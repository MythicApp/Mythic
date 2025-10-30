//
//  LocalGamesExt.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/1/2024.
//

// Copyright © 2023-2025 vapidinfinity

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
