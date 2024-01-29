//
//  URL.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 28/1/2024.
//

import Foundation

extension URL {
    public func prettyPath() -> String { // thx whisky
        return path(percentEncoded: false)
            .replacingOccurrences(of: Bundle.main.bundleIdentifier!, with: "Mythic")
            .replacingOccurrences(of: "/Users/\(NSUserName())", with: "~")
    }
}
