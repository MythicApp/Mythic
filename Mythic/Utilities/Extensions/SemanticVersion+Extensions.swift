//
//  SemanticVersion.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/12/24.
//

// Copyright © 2023-2025 vapidinfinity

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
