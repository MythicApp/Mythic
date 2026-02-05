//
//  Engine+UpdateCatalog.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SemanticVersion

extension Engine {
    struct UpdateCatalog: Decodable {
        /// Native `UpdateCatalog` version this struct is based upon.
        static let nativeVersion: SemanticVersion = .init(0, 2, 0)

        let version: SemanticVersion
        let lastUpdated: Date
        let channels: [Channel]
    }
    
    enum ReleaseChannel: String, Codable {
        case stable
        case preview
    }
}

extension Engine.UpdateCatalog {
    struct Channel: Decodable {
        let name: Engine.ReleaseChannel
        let releases: [Release]

        var latestCompatibleRelease: Release? {
            releases
                .filter { // exclude releases w/ unfulfilled app version requirement
                    guard let minimumAppVersion = $0.minimumAppVersion,
                          let appVersion = Mythic.appVersion
                    else { return true } // keep if appVersion unverifiable/no minimumAppVersion
                    return minimumAppVersion <= appVersion
                    // FIXME: on dirty builds, the prerelease identifier makes the version less than the minimum app version.
                }
                .filter { // exclude releases w/ unfulfilled macOS version requirement
                    guard let minimumMacOSVersion = $0.minimumMacOSVersion,
                          let macOSVersion = SemanticVersion.macOSVersion
                    else { return true }
                    return minimumMacOSVersion <= macOSVersion
                }
                .max(by: { $0.version < $1.version }) // get version w/ highest (thus newest) version
        }
    }
    
    struct Release: Decodable {
        let version: SemanticVersion
        let releaseDate: Date
        let downloadURL: String // cannot use URL type, URLs are stored as dicts for some strange reason
        let checksumURL: String?
        let size: Int?
        let minimumMacOSVersion: SemanticVersion? // upstream MUST have a patch version or this will fail to decode
        let minimumAppVersion: SemanticVersion?
        var targetGPTKVersion: SemanticVersion
        let releaseNotesURL: String?
        let critical: Bool
        let commitSHA: String
    }
}

extension Collection where Element == Engine.UpdateCatalog.Channel {
    // typed lookup by enum
    subscript(_ name: Engine.ReleaseChannel) -> Engine.UpdateCatalog.Channel? {
        first(where: { $0.name == name })
    }
}
