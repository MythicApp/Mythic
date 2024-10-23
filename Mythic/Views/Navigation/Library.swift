//
//  Library.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

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
    @ObservedObject private var variables: VariableManager = .shared

    // MARK: - State Variables
    @State private var isGameImportSheetPresented = false
    @StateObject var gameListViewModel: GameListVM = .shared
    @ObservedObject private var mythicSettings = MythicSettings.shared
    
    // MARK: - Body
    var body: some View {
        GameListEvo()
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

                ToolbarItem(placement: .status) {
                    if variables.getVariable("isLegendaryFetchingInstallableGames") == true {
                        ProgressView()
                            .controlSize(.small)
                            .help("Mythic is checking your Epic library for new games.")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Toggle("Installed", isOn: $gameListViewModel.filterOptions.showInstalled)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Picker("Source", systemImage: "gamecontroller", selection: $gameListViewModel.filterOptions.source) {
                        ForEach(
                            Game.InclusiveSource.allCases,
                            id: \.self
                        ) { source in
                            /*
                            Label(platform.rawValue, systemImage: {
                                switch platform {
                                case .all: "display"
                                case .macOS: "macwindow"
                                case .windows: "pc"
                                }
                            }())
                             */

                            Text(source.rawValue)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Picker("Platform", systemImage: "desktopcomputer.and.arrow.down", selection: $gameListViewModel.filterOptions.platform) {
                        ForEach(Game.InclusivePlatform.allCases, id: \.self) { platform in
                            Text(platform.rawValue)
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Picker("View", systemImage: "desktopcomputer.and.arrow.down", selection: $mythicSettings.data.libraryDisplayMode) {
                        Label("List", systemImage: "list.triangle")
                            .tag(MythicSettings.LibraryDisplayMode.list)
                        
                        Label("Grid", systemImage: "square.grid.2x2")
                            .tag(MythicSettings.LibraryDisplayMode.grid)
                    }
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
