//
//  GameListView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 6/3/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

struct GameListView: View {
    @Bindable var viewModel: GameListViewModel = .shared
    @Bindable var gameDataStore: GameDataStore = .shared
    
    @CodableAppStorage("gameListLayout") var layout: GameListViewModel.Layout = .grid
    @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isGameImportViewPresented: Bool = false

    var body: some View {
        VStack {
            if gameDataStore.library.isEmpty {
                ContentUnavailableView {
                    Label("No Games", systemImage: "gamecontroller")
                } description: {
                    Text("""
                        Games from your signed-in accounts will appear here.
                        You can also import a game that's already on this Mac.
                        """)
                } actions: {
                    Button {
                        isGameImportViewPresented = true
                    } label: {
                        Label("Import Game", systemImage: "plus.app")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh Library") {
                        Task(priority: .userInitiated) {
                            try? await gameDataStore.refreshFromStorefronts()
                        }
                    }
                }
                .task {
                    try? await gameDataStore.refreshFromStorefronts()
                }
                .sheet(isPresented: $isGameImportViewPresented) {
                    GameImportView(isPresented: $isGameImportViewPresented)
                }
            } else {
                ScrollView(.vertical) {
                    // FIXME: sortedLibrary should not be appended to or it'll cause overwrites.
                    // FIXME: a dirtyfix is to directly set to the underlying library
                    if viewModel.sortedLibrary.isEmpty {
                        // the library has games, but none satisfy the current search/filters
                        ContentUnavailableView {
                            Label("No Results", systemImage: "magnifyingglass")
                        } description: {
                            Text("No games match your search and filters.")
                        } actions: {
                            Button("Clear Search and Filters") {
                                viewModel.searchString = .init()
                                viewModel.searchTokens = []
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        switch layout {
                        case .grid:
                            LazyVGrid(columns: [.init(.adaptive(minimum: gameCardSize), spacing: 16)], spacing: 16) {
                                ForEach(viewModel.sortedLibrary) { game in
                                    GameCard(game: .constant(game))
                                }
                            }
                            .padding()
                        case .list:
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.sortedLibrary) { game in
                                    ListGameCard(game: .constant(game))
                                }
                            }
                            .padding()
                        }
                    }
                }
                .searchable(text: $viewModel.searchString,
                            tokens: $viewModel.searchTokens,
                            suggestedTokens: .constant(viewModel.suggestedTokens),
                            placement: .toolbar) { token in
                    switch token {
                    case .platform(let platform):
                        Text(platform.description)
                    case .storefront(let storefront):
                        Text(storefront.description)
                    case .installed:
                        Text("Installed")
                    case .notInstalled:
                        Text("Not Installed")
                    case .favourited:
                        Text("Favourited")
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut, value: layout)
        .animation(reduceMotion ? nil : .default, value: viewModel.sortedLibrary)
    }
}
    
#Preview {
    GameListView()
        .environmentObject(NetworkMonitor.shared)
}
