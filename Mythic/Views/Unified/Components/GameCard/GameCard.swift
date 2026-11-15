//
//  GameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 5/3/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import SwiftyJSON
import Glur
import OSLog

struct GameCard: View {
    @Binding var game: Game

    @State private var isImageEmpty: Bool = true
    @State private var isImageEmptyPreMacOSTahoe: Bool = true

    var body: some View {
        GameImageCard(game: game, url: game.verticalImageURL, isImageEmpty: $isImageEmpty)
            .aspectRatio(3/4, contentMode: .fit)
            .overlay(alignment: .bottom) {
                HStack {
                    VStack(alignment: .leading) {
                        GameCard.TitleAndInformationView(game: $game, font: .title3)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 0)

                    GameCard.ButtonsView(game: $game)
                        .clipShape(.capsule)
                        .progressViewStyle(.circular)
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
                            .padding(.top, 32)
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            // white text directly atop artwork is illegible on bright images
                            .background {
                                if !isImageEmptyPreMacOSTahoe {
                                    ReadabilityScrim()
                                }
                            }
                            .clipShape(.rect(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
                    }
                }
            }
            .overlay(alignment: .top) {
                VStack {
                    if game.isUpdateAvailable == true {
                        VStack {
                            Label("Update available.", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                .help("Update through the game options menu.")
                        }
                        .font(.footnote)
                        .padding(4)
                        .customTransform { view in
                            if #available(macOS 26.0, *) {
                                view.glassEffect(in: .capsule)
                            } else {
                                view.background(in: .capsule)
                            }
                        }
                    }
                }
                .padding()
            }
            // present the card to assistive technologies as one named group, containing its controls.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(GameCard.accessibilityDescription(of: game))
    }
}

extension GameCard {
    /// A spoken summary of a game's title, storefront and state, for use as a card's accessibility label.
    static func accessibilityDescription(of game: Game) -> String {
        var components: [String] = [game.title]

        if let storefront = game.storefront {
            components.append(storefront.description)
        }

        if case .installed = game.installationState {
            components.append(String(localized: "Installed"))
        } else {
            components.append(String(localized: "Not Installed"))
        }

        if game.isFavourited {
            components.append(String(localized: "Favourite"))
        }

        if game.isUpdateAvailable == true {
            components.append(String(localized: "Update available"))
        }

        return components.joined(separator: ", ")
    }
}

/// ViewModifier that enables views to have a fade in effect.
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                if reduceMotion {
                    opacity = 1
                } else {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 1
                    }
                }
            }
    }
}

#Preview {
    GameCard(game: .constant(placeholderGame(type: Game.self)))
        .environmentObject(NetworkMonitor.shared)
}
