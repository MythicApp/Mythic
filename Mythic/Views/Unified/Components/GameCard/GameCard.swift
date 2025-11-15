//
//  GameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/3/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Shimmer
import SwiftyJSON
import Glur
import OSLog

struct GameCard: View {
    @Binding var game: Game

    @State private var isImageEmpty: Bool = true
    @State private var isImageEmptyPreMacOSTahoe: Bool = true

    var body: some View {
        ImageCard(game: $game, isImageEmpty: $isImageEmpty)
            .overlay(alignment: .bottom) {
                gameOverlay
            }
    }

    @ViewBuilder
    var gameOverlay: some View {
        Group {
            HStack {
                VStack(alignment: .leading) {
                    GameCard.TitleAndInformationView(game: $game, font: .title3)
                }
                .layoutPriority(1)

                GameCard.ButtonsView(game: $game)
                    .clipShape(.capsule)
            }
            .padding(.horizontal)
            // conditionally change view foreground style for macOS <26
            .onChange(of: isImageEmpty) {
                if #unavailable(macOS 26.0) {
                    isImageEmptyPreMacOSTahoe = $1
                }
            }
            .conditionalTransform(if: !isImageEmptyPreMacOSTahoe) { view in
                view.foregroundStyle(.white)
            }
        }
        // use liquid glass on macOS 26+
        .customTransform { view in
            if #available(macOS 26.0, *) {
                view
                    .padding(.vertical)
                    .glassEffect(in: .rect(cornerRadius: 20.0))
                    .padding(4)
            } else {
                view
                    .padding(.bottom)
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
            }
        }
    }
}

extension GameCard {
    struct ImageCard: View {
        @Binding var game: Game

        /// Binding that updates when image is empty (default to true)
        @Binding var isImageEmpty: Bool

        @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0

        var withBlur: Bool = true

        var body: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.quinary)
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    gameImage
                }
        }

        @ViewBuilder
        private var gameImage: some View {
            AsyncImage(url: game.imageURL) { phase in
                switch phase {
                case .empty:
                    FallbackImageCard(game: $game)
                        .onAppear {
                            withAnimation { isImageEmpty = true }
                        }

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
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipShape(.rect(cornerRadius: 20))
                                    .blur(radius: gameCardBlur)
                            }
                        }

                        image
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fill)
                            .customTransform { view in
                                if #unavailable(macOS 26.0) {
                                    view.glur(radius: 20,
                                              offset: 0.7,
                                              interpolation: 0.7,
                                              drawingGroup: true)
                                } else {
                                    view
                                }
                            }
                            .clipShape(.rect(cornerRadius: 20))
                            .modifier(FadeInModifier())
                    }
                    .onAppear {
                        withAnimation { isImageEmpty = false }
                    }
                    .onDisappear {
                        withAnimation { isImageEmpty = true }
                    }
                case .failure(let error):
                    ContentUnavailableView(
                        "Unable to load the image.",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init(error.localizedDescription)
                    )
                    .onAppear {
                        withAnimation { isImageEmpty = true }
                    }
                @unknown default:
                    ContentUnavailableView(
                        "Unable to load the image.",
                        systemImage: "photo.badge.exclamationmark",
                        description: .init("""
                            Please check your connection, and try again.
                            """)
                    )
                    .onAppear {
                        withAnimation { isImageEmpty = true }
                    }
                }
            }
            .grayscale({
                if let location = game.location,
                   !files.fileExists(atPath: location.path),
                   game.isInstalled {
                    return 1.0
                }

                return 0.0
            }())
        }
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

#Preview {
    GameCard(game: .constant(placeholderGame(forSource: .local)))
        .environmentObject(NetworkMonitor.shared)
}
