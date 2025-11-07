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
    @ObservedObject var viewModel: GameListVM = .shared

    @AppStorage("isGameListLayoutEnabled") private var isListLayoutEnabled: Bool = false
    @AppStorage("isLibraryGridScrollingVertical") private var isLibraryGridScrollingVertical: Bool = true
    @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0

    @State private var isGameImportViewPresented: Bool = false
    
    var body: some View {
        VStack {
            if unifiedGames.isEmpty {
                ContentUnavailableView(
                    "No games found. 😢",
                    systemImage: "folder.badge.questionmark",
                    description: Text("""
                        Games in your library will appear here.
                        If there are games in your library and they're not appearing, try restarting Mythic.
                        """)
                )

                Button {
                    isGameImportViewPresented = true
                } label: {
                    Label("Import game", systemImage: "plus.app")
                        .padding(5)
                }
                .buttonStyle(.borderedProminent)
                .sheet(isPresented: $isGameImportViewPresented) {
                    GameImportView(isPresented: $isGameImportViewPresented)
                }
            } else if isListLayoutEnabled {
                ScrollView(.vertical) {
                    LazyVStack {
                        ForEach(viewModel.games) { game in
                            ListGameCard(game: .constant(game))
                        }
                    }
                    .padding()
                    .searchable(text: $viewModel.searchString, placement: .toolbar)
                }
            } else {
                if isLibraryGridScrollingVertical {
                    ScrollView(.vertical) {
                        LazyVGrid(columns: [.init(.adaptive(minimum: gameCardSize))]) {
                            ForEach(viewModel.games) { game in
                                GameCard(game: .constant(game))
                            }
                        }
                        .padding()
                        .searchable(text: $viewModel.searchString, placement: .toolbar)
                    }
                } else {
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: [.init(.adaptive(minimum: gameCardSize))]) {
                            ForEach(viewModel.games) { game in
                                GameCard(game: .constant(game))
                            }
                        }
                        .padding()
                        .searchable(text: $viewModel.searchString, placement: .toolbar)
                    }
                }
            }
        }
        .id(viewModel.refreshFlag)
    }
}

#Preview {
    GameListView()
        .environmentObject(NetworkMonitor.shared)
}
