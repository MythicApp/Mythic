//
//  Library.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwiftyJSON
import SwordRPC

// MARK: - LibraryView Struct
/// A view displaying the user's library of games.
struct LibraryView: View {
    @ObservedObject private var gameModification: GameModification = .shared
    
    // MARK: - State Variables
    @State private var addGameModalPresented = false
    @State private var legendaryStatus: JSON = JSON()
    @State private var isGameListRefreshCalled: Bool = false
    @State private var isDownloadsPopoverPresented: Bool = false
    
    @State private var searchText: String = .init()
    
    // MARK: - Body
    var body: some View {
        // GameListView(isRefreshCalled: $isGameListRefreshCalled, searchText: $searchText)
        GameListEvo()
            .navigationTitle("Library")
        
        // MARK: - Toolbar
            .toolbar {
                // MARK: Add Game Button
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addGameModalPresented = true
                    } label: {
                        Image(systemName: "plus.app")
                    }
                    .help("Import a game")
                }
                
                // MARK: Refresh Button
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isGameListRefreshCalled = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh library")
                }
            }
        
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Looking through their game library"
                    presence.state = "Viewing Library"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    
                    return presence
                }())
            }
        
        // MARK: - Other Properties
            .sheet(isPresented: $addGameModalPresented) {
                LibraryView.GameImportView(
                    isPresented: $addGameModalPresented,
                    isGameListRefreshCalled: $isGameListRefreshCalled
                )
                .fixedSize()
            }
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
