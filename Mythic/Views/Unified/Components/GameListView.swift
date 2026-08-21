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
    
    @State private var isGameImportViewPresented: Bool = false
    @State private var isSteamSignInViewPresented: Bool = false
    
    private var importGameButton: some View {
        Button {
            isGameImportViewPresented = true
        } label: {
            Label("Import Game", systemImage: "plus.app")
                .padding(5)
        }
    }

    var body: some View {
        VStack {
            if gameDataStore.library.isEmpty {
                if let progress = viewModel.libraryUpdateProgress {
                    // An empty library during a first Steam enumeration is expected and takes a while, so
                    // it gets a real progress report rather than the same "no games found" as a genuinely
                    // empty one.
                    VStack(spacing: 14) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 34))
                            .foregroundStyle(.tertiary)

                        Text("Loading your library…")
                            .font(.title3.bold())

                        if let fraction = progress.fractionCompleted {
                            ProgressView(value: fraction)
                                .frame(maxWidth: 320)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(progress.label)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "No games found. 😢",
                        systemImage: "folder.badge.questionmark",
                        description: Text("""
                            Games in your library will appear here.
                            If there are games in your library and they're not appearing, try restarting Mythic.
                            """)
                    )
                    .task {
                        try? await gameDataStore.refreshFromStorefronts()
                    }

                    // The empty state used to offer only "Import Game", which is the fallback rather than
                    // the answer: for a storefront, the library arrives by signing in. Whichever
                    // storefronts are not connected are offered here, so the next step is on screen
                    // instead of somewhere in Accounts.
                    HStack {
                        if !Steam.isSignedIn {
                            Button {
                                isSteamSignInViewPresented = true
                            } label: {
                                Label {
                                    Text("Connect Steam")
                                } icon: {
                                    Image("Steam")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                }
                                .padding(5)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        // Importing is the fallback when a storefront is connected, and the primary
                        // action when none is.
                        if Steam.isSignedIn {
                            importGameButton.buttonStyle(.borderedProminent)
                        } else {
                            importGameButton.buttonStyle(.bordered)
                        }
                    }
                    .sheet(isPresented: $isGameImportViewPresented) {
                        GameImportView(isPresented: $isGameImportViewPresented)
                    }
                    .sheet(isPresented: $isSteamSignInViewPresented) {
                        SteamSignInView(isPresented: $isSteamSignInViewPresented)
                            .frame(width: 460)
                    }
                }
            } else {
                ScrollView(.vertical) {
                    // FIXME: sortedLibrary should not be appended to or it'll cause overwrites.
                    // FIXME: a dirtyfix is to directly set to the underlying library
                    switch layout {
                    case .grid:
                        LazyVGrid(columns: [.init(.adaptive(minimum: gameCardSize))]) {
                            ForEach(viewModel.sortedLibrary) { game in
                                GameCard(game: .constant(game))
                            }
                        }
                        .padding()
                    case .list:
                        LazyVStack {
                            ForEach(viewModel.sortedLibrary) { game in
                                ListGameCard(game: .constant(game))
                            }
                        }
                        .padding()
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
        .animation(.easeInOut, value: layout)
        .animation(.default, value: viewModel.sortedLibrary)
    }
}
    
#Preview {
    GameListView()
        .environmentObject(NetworkMonitor.shared)
}
