//
//  CompactGameCard.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 19/5/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

struct CompactGameCard: View {
    @Binding var game: Game
    
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @ObservedObject private var operation: GameOperation = .shared
    @ObservedObject var viewModel: GameCardVM = .init()

    @State private var isLaunchErrorAlertPresented: Bool = false
    @State private var launchError: Error?

    @State private var isImageEmpty: Bool = true

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .aspectRatio(1, contentMode: .fit)
            .overlay { // MARK: Image
                AsyncImage(url: game.wideImageURL ?? game.imageURL) { phase in
                    switch phase {
                    case .empty:
                        GameCard.FallbackImageCard(game: $game, withBlur: false)
                            .blur(radius: 20.0)
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(.rect(cornerRadius: 20))
                            .blur(radius: 20.0)
                            .modifier(FadeInModifier())
                            .onAppear {
                                withAnimation { isImageEmpty = false }
                            }
                            .onDisappear {
                                withAnimation { isImageEmpty = true }
                            }
                    case .failure:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.background)
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.background)
                            .onAppear {
                                withAnimation { isImageEmpty = true }
                            }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack {
                    // MARK: Game Title Stack
                    HStack {
                        Text(game.title)
                            .font(.bold(.title3)())
                            .foregroundStyle(isImageEmpty ? Color.primary : Color.white)

                        Spacer()
                        if game.isLaunching {
                            ProgressView()
                                .controlSize(.small)
                                .clipShape(.circle)
                                .foregroundStyle(.white)
                                .padding(5)
                        } else {
                            GameCardVM.SharedViews.Buttons.PlayButton(game: $game)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                .scaledToFit()
            }
            .overlay(alignment: .topLeading) {
                if game.isFavourited {
                    Image(systemName: "star")
                        .symbolVariant(.fill)
                        .foregroundStyle(isImageEmpty ? Color.primary : Color.white)
                        .padding()
                }
            }
    }
}

#Preview {
    CompactGameCard(game: .constant(.init(source: .epic, title: "test", wideImageURL: .init(string: "https://i.imgur.com/CZt2F4s.png"))))
        .padding()
}
