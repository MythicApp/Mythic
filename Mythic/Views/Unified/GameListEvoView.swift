//
//  GameListEvo.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 6/3/2024.
//

import SwiftUI

struct GameListEvo: View {
    @State private var searchString: String = .init()
    @State private var refresh: Bool = false
    
    @State private var isGameImportViewPresented: Bool = false
    
    private var games: [Game] {
        return unifiedGames
            .filter {
                searchString.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(searchString)
            }
            .sorted(by: { $0.title < $1.title })
            .sorted(by: { $0.isFavourited && !$1.isFavourited })
    }
    
    var body: some View {
        if !unifiedGames.isEmpty {
            ScrollView(.horizontal) {
                LazyHGrid(rows: [.init(.adaptive(minimum: 335))]) {
                    ForEach(games) { game in
                        GameCard(game: .constant(game))
                            .padding([.leading, .vertical])
                    }
                }
                .searchable(text: $searchString, placement: .toolbar)
            }
        } else {
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
                LibraryView.GameImportView(isPresented: $isGameImportViewPresented)
            }
            
        }
    }
}

#Preview {
    GameListEvo()
        .environmentObject(NetworkMonitor())
}
