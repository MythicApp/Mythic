//
//  HeroGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import Glur

// May be unnecesary since used only once (`HomeView`)
struct HeroGameCard: View {
    @Binding var game: Game

    var body: some View {
        EmptyView() // FIXME: stub
    }
}
#Preview {
    GeometryReader { geometry in
        VStack {
            GameImageCard(url: placeholderGame(type: Game.self).horizontalImageURL, isImageEmpty: .constant(false))
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: geometry.size.width,
                       height: geometry.size.height * 0.75)
                .glur(radius: 20,
                      offset: 0.5,
                      interpolation: 0.7,
                      drawingGroup: false)
                .customTransform { view in
                    if #available(macOS 26.0, *) {
                        view.backgroundExtensionEffect()
                    } else {
                        view
                    }
                }
            
            Divider()
            
            Text("Content below the card🔥🔥🔥🔥🧑🏾‍🚒🧑🏾‍🚒🧑🏾‍🚒🧑🏾‍🚒🧑🏾‍🚒🚒🚒🚒🚒🚒🚒")
        }
    }
}
