//
//  HeroGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

// FIXME: stub — may be unnecesary since only used once (`HomeView`)
struct HeroGameCard: View {
    @Binding var game: Game

    var body: some View {

    }
}

extension HeroGameCard {
    struct ImageCard: View {
        @Binding var game: Game
        @Binding var isImageEmpty: Bool

        var body: some View {
            Group {
                if game.wideImageURL != nil {
                    GeometryReader { geometry in
                        AsyncImage(url: game.wideImageURL) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(.quinary)
                                    .shimmering(
                                        animation: .easeInOut(duration: 1)
                                            .repeatForever(autoreverses: false),
                                        bandSize: 1
                                    )
                                    .frame(width: geometry.size.width,
                                           height: geometry.size.height)
                                    .onAppear {
                                        withAnimation { isImageEmpty = true }
                                    }
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .glur(radius: 20,
                                          offset: 0.5,
                                          interpolation: 0.7,
                                          drawingGroup: true)
                                    .modifier(FadeInModifier())
                                    .frame(width: geometry.size.width,
                                           height: geometry.size.height,
                                           alignment: .top)
                                    .onAppear {
                                        withAnimation { isImageEmpty = false }
                                    }
                            case .failure(let error):
                                ContentUnavailableView(
                                    "Unable to load the image.",
                                    systemImage: "photo.badge.exclamationmark",
                                    description: .init(error.localizedDescription)
                                )
                                .frame(width: geometry.size.width,
                                       height: geometry.size.height)
                                .background(.quinary)
                                .onAppear {
                                    withAnimation { isImageEmpty = true }
                                }
                            @unknown default:
                                ContentUnavailableView(
                                    "Unable to load the image.",
                                    systemImage: "photo.badge.exclamationmark",
                                    description: .init("Please check your connection.")
                                )
                                .frame(width: geometry.size.width,
                                       height: geometry.size.height)
                                .background(.quinary)
                                .onAppear {
                                    withAnimation { isImageEmpty = true }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Image Unavailable",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init("""
                            This game doesn't have a widescreen image that Mythic can display.
                            """)
                    )
                }
            }
            .customTransform { view in
                if #available(macOS 26.0, *) {
                    view.backgroundExtensionEffect()
                } else {
                    view
                }
            }
        }
    }
}

#Preview {
    GeometryReader { geometry in
        VStack {
            HeroGameCard.ImageCard(
                game: .constant(placeholderGame(forSource: .local)),
                isImageEmpty: .constant(false)
            )
            .frame(width: geometry.size.width, height: geometry.size.height * 0.75)

            Divider()

            Text("Content below the card")
        }
    }
}
