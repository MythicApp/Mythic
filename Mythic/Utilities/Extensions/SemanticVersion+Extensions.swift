//
//  SemanticVersion.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/12/24.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SemanticVersion

extension SemanticVersion {
    static var macOSVersion: Self? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return .init(version.majorVersion, version.minorVersion, version.patchVersion)
    }

    var prettyString: String {
        var versionString = "\(major).\(minor).\(patch)"
        if !preRelease.isEmpty {
            versionString += "-\(preRelease)"
        }
        if !build.isEmpty {
            versionString += " (\(build))"
        }
        return versionString
    }
}

extension SemanticVersion {

    /// Initialize a semantic version from a relaxed version string (missing patch number, e.g. 7.7) from a string.
    /// Returns `nil` if the string is not of a relaxed version.
    public init?(fromRelaxedString string: String) {
        guard let match = string.wholeMatch(of: relaxedSemanticVersionRegex) else { return nil }
        guard
            let major = Int(match.major),
            let minor = Int(match.minor)
        else { return nil }
        self = .init(major, minor, 0,
                     match.prerelease.map(String.init) ?? "",
                     match.buildmetadata.map(String.init) ?? "")
    }
}

nonisolated(unsafe) let relaxedSemanticVersionRegex = #/
    ^
    v?                              # SPI extension: allow leading 'v'
    (?<major>0|[1-9]\d*)
    \.
    (?<minor>0|[1-9]\d*)
    (?:-
        (?<prerelease>
          (?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)
          (?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*
        )
    )?
    (?:\+
      (?<buildmetadata>[0-9a-zA-Z-]+
        (?:\.[0-9a-zA-Z-]+)
      *)
    )?
    $
    /#
