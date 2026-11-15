//
//  ListGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/20/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Glur
import Shimmer

struct ListGameCard: View {
    @Binding var game: Game
    
    @State private var isImageEmpty: Bool = true
    @State private var isCardExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let defaultHeight: CGFloat = 120
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                GameImageCard(url: game.horizontalImageURL, isImageEmpty: $isImageEmpty, withBlur: !isCardExpanded)
                    .aspectRatio(16/9, contentMode: .fill)
                    .blur(radius: isCardExpanded ? 0 : 30.0)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height,
                           alignment: .center)
                    .conditionalTransform(if: isCardExpanded) { view in
                        view.glur(radius: 18,
                                  offset: 0.6,
                                  interpolation: 0.6)
                    }
            }

            // white text directly atop artwork is illegible on bright images
            if !isImageEmpty {
                ReadabilityScrim()
            }

            HStack {
                if game.isFallbackImageAvailable, isImageEmpty {
                    GameImageCard.FallbackGameImageCard(game: $game)
                        .frame(width: 70, height: 70)
                }
                
                VStack(alignment: .leading) {
                    Text(game.title)
                        .font(.title2.bold())
                        .lineLimit(2)
                        .help(game.title)

                    HStack {
                        GameCard.SubscriptedInfoView(game: $game)
                    }
                }
                .foregroundStyle(isImageEmpty ? .primary : Color.white)
                
                Spacer()
                
                HStack {
                    GameCard.ButtonsView(game: $game)
                        .clipShape(.capsule)
                        .foregroundStyle(isImageEmpty ? .primary : Color.white)
                }
                .frame(maxWidth: 250, alignment: .trailing) // TODO: match operationcard in terms of progressview width limit
            }
            .geometryGroup()
            .padding()
            .frame(maxHeight: .infinity, alignment: isCardExpanded ? .bottom : .center)
        }
        .frame(height: isCardExpanded ? ListGameCard.defaultHeight * 2 : ListGameCard.defaultHeight)
        .clipShape(.rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
        .onHover { hovering in
            if !isImageEmpty {
                withAnimation(reduceMotion ? nil : .default) { isCardExpanded = hovering }
            }
        }
        // present the card to assistive technologies as one named group, containing its controls.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(GameCard.accessibilityDescription(of: game))
    }
}

#Preview {
    ListGameCard(game: .constant(placeholderGame(type: Game.self)))
        .padding()
        .environmentObject(NetworkMonitor.shared)
}
