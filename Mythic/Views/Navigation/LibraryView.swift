//
//  LibraryView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import SwiftyJSON
import SwordRPC

/// A view displaying the user's library of games.
struct LibraryView: View {
    @ObservedObject private var operation: GameOperation = .shared
    @ObservedObject private var variables: VariableManager = .shared
    
    @State private var isGameImportSheetPresented = false
    @ObservedObject var gameListViewModel: GameListViewModel = .shared
    @CodableAppStorage("gameListLayout") var gameListLayout: GameListViewModel.Layout = .grid
    
    var body: some View {
        GameListView()
            .navigationTitle("Library")
        
            .toolbar {
                ToolbarItem(placement: .status) {
                    if variables.getVariable("isUpdatingLibrary") == true {
                        ProgressView()
                            .controlSize(.small)
                            .help("Mythic is updating your library.")
                            .padding(10)
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        isGameImportSheetPresented = true
                    } label: {
                        Label("Import", systemImage: "plus.app")
                    }
                    .help("Import a game")
                }
                
                ToolbarItem(placement: .automatic) {
                    Button("Force-refresh game list", systemImage: "arrow.clockwise", action: gameListViewModel.refresh)
                        .help("Force-refresh the displayed games' status")
                }
                
                ToolbarItem(placement: .automatic) {
                    Picker("View", systemImage: "macwindow", selection: Binding(
                        get: { gameListLayout },
                        set: { newValue in
                            withAnimation {
                                gameListLayout = newValue
                            }
                        }
                    )) {
                        Label("List", systemImage: "rectangle.grid.1x3")
                            .tag(GameListViewModel.Layout.list)
                        
                        Label("Grid", systemImage: "square.grid.3x3")
                            .tag(GameListViewModel.Layout.grid)
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Toggle("Installed", systemImage: "arrow.down.app", isOn: $gameListViewModel.filterOptions.showInstalled)
                        
                        Picker("Platform", systemImage: "desktopcomputer.and.arrow.down", selection: $gameListViewModel.filterOptions.platform) {
                            ForEach(LegacyGame.InclusivePlatform.allCases, id: \.self) { platform in
                                Text(platform.rawValue)
                            }
                        }
                        
                        Picker("Source", systemImage: "gamecontroller", selection: $gameListViewModel.filterOptions.source) {
                            ForEach(
                                LegacyGame.InclusiveSource.allCases,
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
                    } label: {
                        Button("Filters", systemImage: "line.3.horizontal.decrease", action: {  })
                    }
                    .menuIndicator(.hidden)
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
        
            .sheet(isPresented: $isGameImportSheetPresented) {
                GameImportView(isPresented: $isGameImportSheetPresented)
                    .fixedSize()
            }
    }
}

#Preview {
    LibraryView()
        .environmentObject(NetworkMonitor.shared)
        .frame(minHeight: 300)
}
