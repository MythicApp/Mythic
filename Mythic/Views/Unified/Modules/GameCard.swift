//
//  GameCard.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/3/2024.
//

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
        
        var body: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
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
                    handleImage(image)
                        .onAppear {
                            withAnimation { isImageEmpty = false }
                        }
                case .failure:
                    blankImageView
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }
                @unknown default:
                    blankImageView
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }
                }
            }
        }

        /* private FIXME: what */ var handleImage: (Image) -> AnyView = { image in
            AnyView(
                ZStack {
                    image
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fill)
                        .clipShape(.rect(cornerRadius: 20))
                        .blur(radius: 20.0)

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

        var body: some View {
            if case .local = game.source, game.imageURL == nil {
                let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))

                ZStack {
                    image
                        .resizable()
                        .clipShape(.rect(cornerRadius: 20))
                        .blur(radius: 20)

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
