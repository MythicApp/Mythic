//
//  ListGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/20/24.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI

struct ListGameCard: View {
    @Binding var game: Game

    @State private var isImageEmpty: Bool = true

    var body: some View {
        ZStack {
            ListGameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                .ignoresSafeArea()

            HStack {
                if isImageEmpty {
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
        }
    }
}

extension ListGameCard {
    struct ImageCard: View {
        @Binding var game: Game
        @Binding var isImageEmpty: Bool

        @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0

        var body: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.quinary)
                .frame(idealHeight: 120)
                .overlay {
                    AsyncImage(url: game.horizontalImageURL) { phase in
                        switch phase {
                        case .empty:
                            EmptyView()
                                .onAppear {
                                    withAnimation { isImageEmpty = true }
                                }
                        case .success(let image):
                            ZStack {
                                if gameCardBlur > 0 {
                                    image
                                        .resizable()
                                        .clipShape(.rect(cornerRadius: 20))
                                        .blur(radius: gameCardBlur)
                                }

                                image
                                    .resizable()
                                    .blur(radius: 30.0)
                                    .clipShape(.rect(cornerRadius: 20))
                                    .modifier(FadeInModifier())
                                    .onAppear {
                                        withAnimation { isImageEmpty = false }
                                    }
                                    .onDisappear {
                                        withAnimation { isImageEmpty = true }
                                    }
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
        }
    }
}

#Preview {
    ListGameCard(game: .constant(placeholderGame))
        .environmentObject(NetworkMonitor.shared)
}
