//
//  SemanticVersion.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/12/24.
//

import SemanticVersion
extension SemanticVersion {
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
