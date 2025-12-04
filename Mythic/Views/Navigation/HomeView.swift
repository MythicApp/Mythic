//
//  HomeView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import Cocoa
import Glur
import Shimmer
import SwordRPC

/**
 The main view displaying the home screen of the Mythic app.
 */
struct HomeView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Bindable var gameDataStore: GameDataStore = .shared
    
    @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0
    
    @State private var isImageEmpty = true
    
    @State private var isFavouritesSectionExpanded: Bool = true
    @State private var isContainersSectionExpanded: Bool = true

    private var favouriteGamesExcludingRecent: [Game] {
        gameDataStore.library
            .filter(\.self.isFavourited)
            .filter({ $0 != gameDataStore.recent })
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let recentGame = gameDataStore.recent {
                    ZStack(alignment: .bottomLeading) {
                        GameImageCard(url: recentGame.horizontalImageURL, isImageEmpty: $isImageEmpty)
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                            .glur(radius: 18,
                                  offset: 0.6,
                                  interpolation: 0.6)
                            .customTransform { view in
                                if #available(macOS 26.0, *) {
                                    view.backgroundExtensionEffect()
                                } else {
                                    view
                                }
                            }

                        HStack {
                            if isImageEmpty, recentGame.isFallbackImageAvailable {
                                GameCard.FallbackImageCard(game: .constant(recentGame))
                                    .frame(width: 65, height: 65)
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.trailing)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("CONTINUE PLAYING")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                
                                HStack {
                                    GameCard.TitleAndInformationView(game: .constant(recentGame), withSubscriptedInfo: true)
                                }
                                HStack {
                                    GameCard.ButtonsView(game: .constant(recentGame), withLabel: true)
                                        .clipShape(.capsule)
                                }
                            }
                            .conditionalTransform(if: !isImageEmpty) { view in
                                view
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding([.leading, .bottom])
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
                        if favouriteGamesExcludingRecent.isEmpty {
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
                                ForEach(favouriteGamesExcludingRecent) { game in
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
        .customTransform { view in
            if #available(macOS 15.0, *) {
                view
                    .toolbar(removing: .title)
                    .toolbarBackgroundVisibility(.hidden) // dirtyfixes toolbar reappearance on view reload in navigationsplitview
            } else {
                view
                    .toolbarBackground(.hidden) // dirtyfixes toolbar reappearance on view reload in navigationsplitview
            }
        }

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

#Preview {
    HomeView()
        .environmentObject(NetworkMonitor.shared)
}
