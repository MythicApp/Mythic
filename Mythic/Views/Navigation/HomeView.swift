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
    
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    
    @State private var isAlertPresented: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    var body: some View {
        HStack {
            // MARK: - Recent Game Display
            if let recentlyPlayedObject = defaults.object(forKey: "recentlyPlayed") as? Data,
               var recentlyPlayedGame: Game = try? PropertyListDecoder().decode(Game.self, from: recentlyPlayedObject),
               recentlyPlayedGame.isInstalled {
                GameCard(game: .init(get: { recentlyPlayedGame }, set: { recentlyPlayedGame = $0 }))
            }
            
            // MARK: - Side Views
            VStack {
                // MARK: View 1 (Top)
                VStack {
                    if !unifiedGames.filter({ $0.isFavourited == true }).isEmpty {
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: [.init(.adaptive(minimum: 115))]) {
                                ForEach(unifiedGames.filter({ $0.isFavourited == true })) { game in
                                    CompactGameCard(game: .constant(game))
                                        .padding(5)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "star")
                                .symbolVariant(.fill)
                            
                            Text("No games are favourited.")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .clipShape(.rect(cornerRadius: 20))
                
                // MARK: View 2 (Bottom)
                VStack {
                    ContainerListView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .clipShape(.rect(cornerRadius: 20))
            }
        }
        .navigationTitle("Home")
        .padding()
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
