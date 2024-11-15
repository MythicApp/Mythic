//
//  Color.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/2/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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
