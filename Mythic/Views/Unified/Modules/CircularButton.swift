//
//  CircularButton.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 26/6/2024.
//

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
