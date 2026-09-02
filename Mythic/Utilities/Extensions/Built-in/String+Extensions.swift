//
//  String.swift
//  Mythic
//
//  Created by zenfty on 13/6/2025.
//

// Copyright © 2023-2026 zenfty

extension String {
    var sentenceCased: String {
        guard !self.isEmpty else { return self }
        let lowercased = self.lowercased()
        let first = lowercased.prefix(1).capitalized
        let rest = lowercased.dropFirst()
        return first + rest + "."
    }
}
