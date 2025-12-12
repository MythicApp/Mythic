//
//  TimeInterval+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

extension TimeInterval {
    init?(HH_MM_SSString string: String) {
        let parts = string.split(separator: ":")
            .compactMap { Int($0) }

        guard !parts.isEmpty else { return nil }

        switch parts.count {
        case 3: self = TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        case 2: self = TimeInterval(parts[0] * 60 + parts[1])
        case 1: self = TimeInterval(parts[0])
        default: return nil
        }
    }
}
