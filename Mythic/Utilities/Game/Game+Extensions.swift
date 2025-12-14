//
//  Game+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import UniformTypeIdentifiers

extension Game {
    enum ImageType {
        case vertical
        case horizontal
        case custom(URL)
    }

    /// Enumeration containing the two different game platforms available.
    enum Platform: CustomStringConvertible, CaseIterable, Codable, Hashable, Equatable {
        case macOS
        case windows

        var description: String {
            switch self {
            case .macOS:    "macOS"
            case .windows:  "Windows®"
            }
        }

        var allowedExecutableContentTypes: [UTType] {
            switch self {
            case .macOS:    [.application] // technically a bundle but if you came into the codebase to say that then you're a nerd
            case .windows:  [.exe]
            }
        }
    }

    /// Enumeration containing all available game storefronts.
    enum Storefront: CustomStringConvertible, CaseIterable, Codable, Hashable {
        case epicGames
        case local

        var description: String {
            switch self {
            case .epicGames:    String(localized: "Epic Games")
            case .local:        String(localized: "Local")
            }
        }
    }

    enum Compatibility: CustomStringConvertible, CaseIterable {
        case unplayable
        case launchable
        case runnable
        case playable
        case excellent

        var description: String {
            switch self {
            case .unplayable:   String(localized: "The game doesn't launch.")
            case .launchable:   String(localized: "The game launches, but you are unable to play.")
            case .runnable:     String(localized: "The game launches and you are able to play, but some game features are nonfunctional.")
            case .playable:     String(localized: "The game runs well, and is mostly feature-complete.")
            case .excellent:    String(localized: "The game runs well, and is feature-complete.")
            }
        }
    }

    enum InstallationState: CustomStringConvertible, Codable {
        case uninstalled
        case installed(location: URL, platform: Platform)

        var description: String {
            switch self {
            case .uninstalled:  String(localized: "Uninstalled")
            case .installed:    String(localized: "Installed")
            }
        }
    }
}

extension Game.InstallationState: Comparable {
    static func < (lhs: Game.InstallationState, rhs: Game.InstallationState) -> Bool {
        switch (lhs, rhs) {
        case (.uninstalled, .installed):    true
        default:                            false
        }
    }
}
