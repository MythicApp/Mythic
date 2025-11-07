//
//  URL.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 28/1/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension URL {
    public func prettyPath() -> String {
        return path(percentEncoded: false)
            .replacingOccurrences(of: Bundle.main.bundleIdentifier!, with: "Mythic")
            .replacingOccurrences(of: "/Users/\(NSUserName())", with: "~")
            .replacingOccurrences(of: "file://", with: "")
    }
}
