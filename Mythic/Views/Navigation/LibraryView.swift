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
    @ObservedObject private var variables: VariableManager = .shared

    @State private var isGameImportSheetPresented = false
    @Bindable var gameListViewModel: GameListViewModel = .shared
    @CodableAppStorage("gameListLayout") var gameListLayout: GameListViewModel.Layout = .grid

    var body: some View {
        GameListView()
            .navigationTitle("Library")
        
            .toolbar {
                ToolbarItem(placement: .status) {
                    if gameListViewModel.isUpdatingLibrary {
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
                
                // MARK: GameListView filter views
                if !gameListViewModel.library.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button("Force-refresh game list", systemImage: "arrow.clockwise") {
                            Task(priority: .userInitiated, operation: { try? await Game.store.refreshFromStorefronts() })
                        }
                        .help("Force-refresh the displayed games' status")
                    }
                    
                    ToolbarItem(placement: .automatic) {
                        Picker("View", systemImage: "macwindow", selection: $gameListLayout) {
                            Label("List", systemImage: "rectangle.grid.1x3")
                                .tag(GameListViewModel.Layout.list)
                            
                            Label("Grid", systemImage: "square.grid.3x3")
                                .tag(GameListViewModel.Layout.grid)
                        }
                        .animation(.easeInOut, value: $gameListLayout.wrappedValue)
                    }
                    
                    ToolbarItem(placement: .automatic) {
                        Menu("Filters", systemImage: "line.3.horizontal.decrease") {
                            Section("Platform") {
                                ForEach(Game.Platform.allCases, id: \.self) { platform in
                                    Toggle(platform.description,
                                           isOn: searchTokenBinding(for: .platform(platform)))
                                }
                            }
                            
                            Section("Storefront") {
                                ForEach(Game.Storefront.allCases, id: \.self) { storefront in
                                    Toggle(storefront.description,
                                           isOn: searchTokenBinding(for: .storefront(storefront)))
                                }
                            }
                            
                            Section("Installation") {
                                Toggle("Installed",
                                       isOn: searchTokenBinding(for: .installed))
                                Toggle("Not Installed",
                                       isOn: searchTokenBinding(for: .notInstalled))
                            }
                            
                            Section {
                                Toggle("Favourited", isOn: searchTokenBinding(for: .favourited))
                            }
                        }
                        .menuIndicator(.hidden)
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
        
            .sheet(isPresented: $isGameImportSheetPresented) {
                GameImportView(isPresented: $isGameImportSheetPresented)
                    .fixedSize()
            }
    }
    
    private func searchTokenBinding(for token: GameListViewModel.SearchToken) -> Binding<Bool> {
        .init(
            get: { gameListViewModel.searchTokens.contains(token) },
            set: { isOn in
                if isOn {
                    gameListViewModel.searchTokens.append(token)
                } else {
                    gameListViewModel.searchTokens.removeAll { $0 == token }
                }
            }
        )
    }
}

#Preview {
    LibraryView()
        .environmentObject(NetworkMonitor.shared)
        .frame(minHeight: 300)
}
