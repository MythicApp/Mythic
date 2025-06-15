//
//  SubscriptedTextView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 20/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

struct SubscriptedTextView: View {
    init(_ text: String) {
        self.text = text
    }
    
    var text: String = .init()
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 5)
            .overlay( // based off .buttonStyle(.accessoryBarAction)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.tertiary)
            )
    }
}

#Preview {
    SubscriptedTextView("Test Text")
        .padding()
}
