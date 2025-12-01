//
//  ListGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/20/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Glur

struct ListGameCard: View {
    @Binding var game: Game
    
    @State private var isImageEmpty: Bool = true
    @State private var isCardExpanded: Bool = false
    
    static let defaultHeight: CGFloat = 120
    
    var body: some View {
        ListGameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
        /* FIXME: view refresh with glur effect causes total image refresh, causing MenuView sheets to unpresent
           FIXME: unrectifiable with .id, potentially a ZStack would fix it, isolating the refresh to the image, not MenuView
            .conditionalTransform(if: isCardExpanded && !isImageEmpty) { view in
                // causes 'ghost' visual artifact, but might be a W sacrifice for readability
                view
                    .glur(radius: 20,
                          offset: 0.7,
                          interpolation: 0.7,
                          drawingGroup: true)
            }
         */
            .frame(height: isCardExpanded ? ListGameCard.defaultHeight * 2 : ListGameCard.defaultHeight)
            .blur(radius: isCardExpanded ? 0 : 30.0)
            .overlay(alignment: isCardExpanded ? .bottom : .center) {
                HStack {
                    if game.isFallbackImageAvailable, isImageEmpty {
                        GameCard.FallbackImageCard(game: $game)
                            .frame(width: 70, height: 70)
                            .padding()
                    }
                    
                    VStack(alignment: .leading) {
                        Text(game.title)
                            .font(.system(.title, weight: .bold))
                        
                        HStack {
                            GameCard.SubscriptedInfoView(game: $game)
                        }
                    }
                    .foregroundStyle(isImageEmpty ? Color.primary : Color.white)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Group {
                        GameCard.ButtonsView(game: $game)
                            .clipShape(.capsule)
                            .conditionalTransform(if: isImageEmpty) { view in
                                view
                                    .foregroundStyle(.white)
                            }
                    }
                    .padding(.trailing)
                }
                .padding(.vertical)
            }
            .clipShape(.rect(cornerRadius: 20))
            .contentShape(.rect(cornerRadius: 20))
            .onHover { hovering in
                if !isImageEmpty {
                    withAnimation { isCardExpanded = hovering }
                }
            }
    }
}

extension ListGameCard {
    struct ImageCard: View {
        @Binding var game: Game
        @Binding var isImageEmpty: Bool
        
        var withBlur: Bool = true
        
        @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0
        
        var body: some View {
            GeometryReader { geometry in
                AsyncImage(url: game.horizontalImageURL) { phase in
                    switch phase {
                    case .empty:
                        Color.clear
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .frame(width: geometry.size.width,
                                   height: geometry.size.height)
                            .shimmering(
                                animation: .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                bandSize: 1
                            )
                    case .success(let image):
                        ZStack {
                            // blurred image as background
                            // save resources by only create this image if it'll be used for blur
                            if withBlur && (gameCardBlur > 0) {
                                // save resources by decreasing resolution scale of blurred image
                                let renderer: ImageRenderer = {
                                    let renderer = ImageRenderer(content: image)
                                    renderer.scale = 0.2
                                    return renderer
                                }()

                                if let image = renderer.cgImage {
                                    Image(image, scale: 1, label: .init(""))
                                        .resizable()
                                        .clipShape(.rect(cornerRadius: 20))
                                        .blur(radius: gameCardBlur)
                                }
                            }
                            
                            image
                                .resizable()
                                .modifier(FadeInModifier())
                                .onAppear {
                                    withAnimation { isImageEmpty = false }
                                }
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                    case .failure:
                        Color.clear
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .frame(width: geometry.size.width,
                                   height: geometry.size.height)
                            .shimmering(
                                animation: .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                bandSize: 1
                            )
                    @unknown default:
                        Color.clear
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                            .frame(width: geometry.size.width,
                                   height: geometry.size.height)
                            .shimmering(
                                animation: .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                bandSize: 1
                            )
                    }
                }
                .background(.quinary)
                .clipShape(.rect(cornerRadius: 20))
            }
        }
    }
}

#Preview {
    ListGameCard(game: .constant(placeholderGame(type: Game.self)))
        .padding()
        .environmentObject(NetworkMonitor.shared)
}
