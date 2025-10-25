//
//  Engine+Appcast.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2025.
//

import Foundation
import SemanticVersion

extension Engine {
    struct UpdateCatalog: Codable {
        let version: Int
        let lastUpdated: Date
        let channels: [Channel]

        struct Channel: Codable {
            let name: ReleaseChannel
            let releases: [Release]

            var latestRelease: Release? {
                releases.max(by: { $0.version < $1.version })
            }
        }

        struct Release: Codable {
            let version: SemanticVersion
            let releaseDate: Date
            let downloadURL: String
            let checksumURL: String?
            let size: Int
            let minimumMacOSVersion: String?
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

extension Collection where Element == Engine.UpdateCatalog.Channel {
    // typed lookup by enum
    subscript(_ name: Engine.ReleaseChannel) -> Engine.UpdateCatalog.Channel? {
        first(where: { $0.name == name })
    }
}
