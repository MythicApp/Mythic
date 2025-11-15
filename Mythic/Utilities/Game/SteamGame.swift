//
//  SteamGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

// haha you thought

import Foundation

@available(*, deprecated, message: "Soon...")
class SteamGame: Game {
    required init(id: String = UUID().uuidString,
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
}
