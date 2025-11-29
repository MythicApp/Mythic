//
//  Mergeable.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 23/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

protocol Mergeable {
    mutating func merge(with other: Self)
}

extension Mergeable where Self: Codable {
    // i advise against using this, i just included it because meh
    func merged(with other: Self) -> Self? {
        guard let encoded = try? PropertyListEncoder().encode(self) else { return nil }
        var copy = try? PropertyListDecoder().decode(Self.self, from: encoded)

        copy?.merge(with: other)
        return copy
    }
}
