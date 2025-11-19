//
//  Game+Extensions.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension Game {
    enum ImageType {
        case vertical
        case horizontal
        case custom(URL)
    }

    /// Enumeration containing the two different game platforms available.
    enum Platform: String, CaseIterable, Codable, Hashable {
        case macOS = "macOS"
        case windows = "Windows®"
    }

    /// Enumeration containing all available game storefronts.
    enum Storefront: String, CaseIterable, Codable, Hashable {
        case epicGames = "Epic Games"
        case local = "Local"
    }

    enum Compatibility: String, CaseIterable {
        case unplayable = "The game doesn't launch."
        case launchable = "The game launches, but you are unable to play."
        case runnable = "The game launches and you are able to play, but some game features are nonfunctional."
        case playable = "The game runs well, and is mostly feature-complete."
        case excellent = "The game runs well, and is feature-complete."
    }

    enum InstallationState: Codable {
        case uninstalled
        case installed(location: URL, platform: Platform)
    }
}
