//
//  HomeView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Cocoa
import Glur
import Shimmer
import SwordRPC

// MARK: - HomeView Struct
/**
 The main view displaying the home screen of the Mythic app.
 */
struct HomeView: View {
    @ObservedObject private var variables: VariableManager = .shared
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0

    @State private var isImageEmpty = true

    @State private var isFavouritesSectionExpanded: Bool = true
    @State private var isContainersSectionExpanded: Bool = true

    @State private var favouritesExcludingRecent = unifiedGames.filter({ $0.isFavourited && $0 != (try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed")) })

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let recentGame = try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed") {
                    ZStack(alignment: .bottomLeading) {
                        HeroGameCard.ImageCard(game: .constant(recentGame), isImageEmpty: $isImageEmpty)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.75)

                        VStack(alignment: .leading) {
                            Text("CONTINUE PLAYING")
                                .foregroundStyle(.placeholder)
                                .font(.caption)

                            HStack {
                                GameCardVM.TitleAndInformationView(game: .constant(recentGame), withSubscriptedInfo: false)
                                SubscriptedTextView(recentGame.source.rawValue)
                            }
                            HStack {
                                GameCardVM.ButtonsView(game: .constant(recentGame), withLabel: true)
                                    .clipShape(.capsule)
                            }
                        }
                        .padding([.leading, .bottom])
                        .conditionalTransform(if: !isImageEmpty) { view in
                            view
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: geometry.size.height * 0.75)
                } else {
                    ContentUnavailableView(
                        "Welcome to Mythic!",
                        systemImage: "hand.wave",
                        description: .init("""
                        This area is where your most recently played game will appear — try launching one now!
                        """)
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height * 0.75
                    )
                    .background(.quinary)
                }

                Form {
                    Section("Your Favourites", isExpanded: $isFavouritesSectionExpanded) {
                        if favouritesExcludingRecent.isEmpty {
                            HStack(alignment: .center) {
                                Spacer()
                                ContentUnavailableView(
                                    "No Favourites",
                                    systemImage: "star.slash.fill",
                                    description: .init("""
                                    Games you favourite will appear here.
                                    You can favourite a game by pressing [􀍠] → [􀋂].
                                    """)
                                )
                                Spacer()
                            }
                        } else {
                            LazyVGrid(columns: [.init(.adaptive(minimum: gameCardSize))]) {
                                ForEach(favouritesExcludingRecent) { game in
                                    GameCard(game: .constant(game))
                                }
                            }
                        }
                    }

                    Section("Your Containers", isExpanded: $isContainersSectionExpanded) {
                        ContainerListView()
                    }

                }
                .formStyle(.grouped)
            }
        }
        .ignoresSafeArea(edges: .top)

        .navigationTitle("Home")
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Viewing home"
                presence.state = "Idle"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"

                return presence
            }())
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(NetworkMonitor.shared)
}
