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
    @ObservedObject private var operation: GameOperation = .shared
    
    // MARK: - State Variables
    @State private var isGameImportSheetPresented = false
    @State private var filterOptions: GameListFilterOptions = .init()
    @ObservedObject private var data = DatabaseData.shared
    
    // MARK: - Body
    var body: some View {
        GameListEvo(filterOptions: $filterOptions)
            .navigationTitle("Library")
        
        // MARK: - Toolbar
            .toolbar {
                // MARK: Add Game Button
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isGameImportSheetPresented = true
                    } label: {
                        Label("Import", systemImage: "plus.app")
                    }
                    .help("Import a game")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Toggle("Installed", isOn: $filterOptions.showInstalled)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Picker("Source", systemImage: "gamecontroller", selection: $filterOptions.source) {
                        ForEach(InclusiveGameSource.allCases, id: \.self) { source in
                            Text(source.rawValue)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Picker("Platform", systemImage: "desktopcomputer.and.arrow.down", selection: $filterOptions.platform) {
                        ForEach(InclusiveGamePlatform.allCases, id: \.self) { platform in
                            Label(platform.rawValue, systemImage: {
                                switch platform {
                                case .all: "display"
                                case .mac: "macwindow"
                                case .windows: "pc"
                                }
                            }())
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Picker("View", systemImage: "desktopcomputer.and.arrow.down", selection: $data.data.libraryDisplayMode) {
                        Label("List", systemImage: "list.triangle").tag(DatabaseData.LibraryDisplayMode.list)
                        Label("Grid", systemImage: "square.grid.2x2").tag(DatabaseData.LibraryDisplayMode.grid)
                    }
#if !DEBUG
                    .disabled(true)
#endif
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
            .sheet(isPresented: $isGameImportSheetPresented) {
                GameImportView(isPresented: $isGameImportSheetPresented)
                    .fixedSize()
            }
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
        .environmentObject(SparkleController())
}
