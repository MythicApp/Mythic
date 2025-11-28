//
//  HeroGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

// May be unnecesary since used only once (`HomeView`)
struct HeroGameCard: View {
    @Binding var game: Game

    var body: some View {
        EmptyView() // FIXME: stub
    }
}

extension HeroGameCard {
    struct ImageCard: View {
        @Binding var game: Game
        @Binding var isImageEmpty: Bool

        var body: some View {
                if let horizontalImageURL = game.horizontalImageURL {
                    GeometryReader { geometry in
                        AsyncImage(url: horizontalImageURL) { phase in
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
                                .backgroundStyle(.quinary)
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
                                .backgroundStyle(.quinary)
                                .onAppear {
                                    withAnimation { isImageEmpty = true }
                                }
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
    }
}

#Preview {
    GeometryReader { geometry in
        VStack {
            HeroGameCard.ImageCard(game: .constant(placeholderGame(type: Game.self)),
                                   isImageEmpty: .constant(false))
            .frame(width: geometry.size.width,
                   height: geometry.size.height * 0.75)

            Divider()

            Text("Content below the card🔥🔥🔥🔥🧑🏾‍🚒🧑🏾‍🚒🧑🏾‍🚒🧑🏾‍🚒🧑🏾‍🚒🚒🚒🚒🚒🚒🚒")
        }
    }
}
