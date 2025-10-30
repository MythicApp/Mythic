//
//  Engine+Appcast.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SemanticVersion

// swiftlint:disable nesting
extension Engine {
    struct UpdateCatalog: Codable {
        /// Native `UpdateCatalog` version this struct is based upon.
        static let nativeVersion: SemanticVersion = .init(0, 1, 0)

        let version: SemanticVersion
        let lastUpdated: Date
        let channels: [Channel]

        struct Channel: Codable {
            let name: ReleaseChannel
            let releases: [Release]

            var latestRelease: Release? {
                releases
                    .filter { // exclude releases w/ unfulilled app version requirement
                        guard let minimumAppVersion = $0.minimumAppVersion,
                              let appVersion = Mythic.appVersion
                        else { return true } // keep if appVersion unverifiable/no minimumAppVersion
                        return minimumAppVersion <= appVersion
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

        struct Release: Codable {
            let version: SemanticVersion
            let releaseDate: Date
            let downloadURL: String // cannot use URL type, URLs are stored as dicts for some strange reason
            let checksumURL: String?
            let size: Int?
            let minimumMacOSVersion: SemanticVersion? // upstream MUST have a patch version or this will fail to decode
            let minimumAppVersion: SemanticVersion?
            let releaseNotesURL: String?
            let critical: Bool
            let commitSHA: String
        }
    }

    enum ReleaseChannel: String, Codable {
        case stable
        case preview
    }
}
// swiftlint:enable nesting

extension Collection where Element == Engine.UpdateCatalog.Channel {
    // typed lookup by enum
    subscript(_ name: Engine.ReleaseChannel) -> Engine.UpdateCatalog.Channel? {
        first(where: { $0.name == name })
    }
}
