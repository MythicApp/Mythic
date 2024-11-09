//
//  CircularButton.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 26/6/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

// TODO: WIP
struct CircularButton: View {
    let action: () -> Void
    let hoverColor: Color?
    let image: Image
    
    @State private var isHoveringOverDestructiveButton: Bool = false

    init(image: Image, hoverColor: Color? = nil, action: @escaping () -> Void) {
        self.image = image
        self.hoverColor = hoverColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                image
                    .padding([.vertical, .trailing], 5)
                    .foregroundColor(isHoveringOverDestructiveButton ? hoverColor : .primary)
            }
        }
        .clipShape(.circle)
        .onHover { hovering in
            if hoverColor != nil {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHoveringOverDestructiveButton = hovering
                }
            }
        }
    }
}

#Preview {
    HStack {
        CircularButton(image: Image(systemName: "trash"), hoverColor: .red) {
            print("trash clicked")
        }
        
        CircularButton(image: Image(systemName: "info"), hoverColor: nil) {
            print("info clicked")
        }
    }
    .padding()
}
