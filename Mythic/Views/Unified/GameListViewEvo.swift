//
//  GameListEvo.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 6/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI

struct GameListEvo: View {
    @ObservedObject var viewModel: GameListVM = .shared
    @ObservedObject private var variables: VariableManager = .shared

    @AppStorage("isGameListLayoutEnabled") private var isListLayoutEnabled: Bool = false
    @AppStorage("isLibraryGridScrollingVertical") private var isLibraryGridScrollingVertical: Bool = false
    @AppStorage("gameCardSize") private var gameCardSize: Double = 250.0

    @State private var isGameImportViewPresented: Bool = false
    
    var body: some View {
        VStack {
            if unifiedGames.isEmpty {
                Text("No games can be shown.")
                    .font(.bold(.title)())

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
                            GameListCard(game: .constant(game))
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
    GameListEvo()
        .environmentObject(NetworkMonitor.shared)
}
