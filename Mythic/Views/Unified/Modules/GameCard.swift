//
//  GameCard.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Shimmer
import SwiftyJSON
import CachedAsyncImage
import Glur
import OSLog

struct GameCard: View {
    @Binding var game: Game
    @ObservedObject var viewModel: GameCardVM = .init()

    @State private var isImageEmpty: Bool = true

    var body: some View {
        ImageCard(game: $game, isImageEmpty: $isImageEmpty)
            .overlay(alignment: .bottom) {
                gameOverlay
            }
    }

    @ViewBuilder
    var gameOverlay: some View {
        VStack {
            gameTitleStack

            GameCardVM.SharedViews.ButtonsView(game: $game)
        }
        .padding(.bottom)
        .frame(maxWidth: .infinity)
    }

    var gameTitleStack: some View {
        HStack {
            Text(game.title)
                .font(.bold(.title3)())
                .truncationMode(.tail)
                .lineLimit(1)

            GameCardVM.SharedViews.SubscriptedInfoView(game: $game)

            Spacer()
        }
        .padding(.leading)
        .foregroundStyle(isImageEmpty ? Color.primary : Color.white)
    }
}

/// ViewModifier that enables views to have a fade in effect.
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    opacity = 1
                }
            }
    }
}

extension GameCard {
    struct ImageCard: View {
        @Binding var game: Game

        /// Binding that updates when image is empty (default to true)
        @Binding var isImageEmpty: Bool

        var withBlur: Bool = true

        var body: some View {
            blankImageView
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    gameImage
                }
        }

        @ViewBuilder
        private var gameImage: some View {
            CachedAsyncImage(url: game.imageURL) { phase in
                switch phase {
                case .empty:
                    FallbackImageCard(game: $game)
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }
                case .success(let image):
                    handleImage(image, withBlur)
                        .onAppear {
                            withAnimation { isImageEmpty = false }
                        }
                case .failure:
                    EmptyView()
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }
                @unknown default:
                    EmptyView()
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }
                }
            }
        }

        /* private FIXME: what */ var handleImage: (Image, Bool) -> AnyView = { image, withBlur in
            AnyView(
                ZStack {
                    if withBlur {
                        image
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fill)
                            .clipShape(.rect(cornerRadius: 20))
                            .blur(radius: 20.0)
                    }

                    image
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fill)
                        .glur(radius: 20, offset: 0.5, interpolation: 0.7)
                        .clipShape(.rect(cornerRadius: 20))
                        .modifier(FadeInModifier())
                }
            )
        }

        private var blankImageView: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
        }
    }

    struct FallbackImageCard: View {
        @Binding var game: Game
        var withBlur: Bool = true

        var body: some View {
            if case .local = game.source, game.imageURL == nil {
                let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))

                ZStack {
                    if withBlur {
                        image
                            .resizable()
                            .clipShape(.rect(cornerRadius: 20))
                            .blur(radius: 20)
                    }

                    image
                        .resizable()
                        .scaledToFit()
                        .modifier(FadeInModifier())
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.windowBackground)
                    .shimmering(
                        animation: .easeInOut(duration: 1)
                            .repeatForever(autoreverses: false),
                        bandSize: 1
                    )
            }
        }
    }
}

#Preview {
    GameCard(game: .constant(.init(source: .epic, title: "MRAAAHH")))
        .environmentObject(NetworkMonitor())
}
