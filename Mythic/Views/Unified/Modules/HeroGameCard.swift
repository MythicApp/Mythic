//
//  HeroGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 18/10/2025.
//

import Foundation
import SwiftUI

struct HeroGameImageCard: View {
    @Binding var game: Game
    @State private var isImageEmpty: Bool = false

    var body: some View {
        if game.wideImageURL != nil {
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
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .glur(radius: 20, offset: 0.65, interpolation: 0.7)
                        .modifier(FadeInModifier())
                        .onAppear {
                            withAnimation { isImageEmpty = false }
                        }
                case .failure(let error):
                    ContentUnavailableView(
                        "Unable to load the image.",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init(error.localizedDescription)
                    )
                    .background(.quinary)
                    .onAppear {
                        withAnimation { isImageEmpty = false }
                    }
                @unknown default:
                    ContentUnavailableView(
                        "Unable to load the image.",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init("""
                        Please check your connection, and try again.
                        """)
                    )
                    .background(.quinary)
                    .onAppear {
                        withAnimation { isImageEmpty = false }
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

#Preview {
    GeometryReader { geometry in
        VStack {
            HeroGameImageCard(game: .constant(.init(source: .local, title: "test")))
                .frame(width: geometry.size.width, height: geometry.size.height * 0.75)

            Divider()

            Text("Content below the card")
        }
    }
}
