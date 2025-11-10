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
    
    @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0
    
    @State private var isImageEmpty = true
    
    @State private var isFavouritesSectionExpanded: Bool = true
    @State private var isContainersSectionExpanded: Bool = true
    
    @State private var favouritesExcludingRecent = unifiedGames.filter({ $0.isFavourited && $0 != (try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed")) })
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let recentGame = try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed") {
                    ZStack(alignment: .bottomLeading) {
                        HeroGameCard.ImageCard(game: .constant(recentGame), isImageEmpty: $isImageEmpty)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                        
                        HStack {
                            if isImageEmpty, recentGame.isFallbackImageAvailable {
                                GameCard.FallbackImageCard(game: .constant(recentGame))
                                    .frame(width: 65, height: 65)
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.trailing)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("CONTINUE PLAYING")
                                    .foregroundStyle(.placeholder)
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
        .customTransform { view in
            if #available(macOS 15.0, *) {
                view
                    .toolbar(removing: .title)
            } else {
                view
            }
        }

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
