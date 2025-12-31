//
//  Color.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 9/2/2024.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SwiftUI

extension Color {
    init(hex: String, alpha: Double =  1.0) {
        let hexSanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 =  0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb &  0xFF0000) >>  16) / 255.0
        let green = Double((rgb &  0x00FF00) >>  8) / 255.0
        let blue = Double(rgb &  0x0000FF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func random(randomOpacity: Bool = false) -> Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            opacity: randomOpacity ? .random(in: 0...1) : 1
        )
    }
}
