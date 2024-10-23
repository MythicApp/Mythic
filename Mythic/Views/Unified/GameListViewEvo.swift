import Foundation
import SwiftUI

struct GameListEvo: View {
    @Binding var filterOptions: GameListFilterOptions
    @ObservedObject private var data = MythicSettings.shared
    
    @State private var searchString: String = .init()
    @State private var isGameImportViewPresented: Bool = false
    
    private var games: [Game] {
        let filteredGames = filterGames(unifiedGames)
        return sortGames(filteredGames)
    }
    
    private func filterGames(_ games: [Game]) -> [Game] {
        games.filter { game in
            let matchesSearch = searchString.isEmpty || game.title.localizedCaseInsensitiveContains(searchString)
            let matchesInstalled = !filterOptions.showInstalled || isGameInstalled(game)
            let matchesPlatform = filterOptions.platform == .all || game.platform?.rawValue == filterOptions.platform.rawValue
            let matchesSource = filterOptions.source == .all || game.source.rawValue == filterOptions.source.rawValue
            
            return matchesSearch && matchesInstalled && matchesPlatform && matchesSource
        }
    }
    
    private func isGameInstalled(_ game: Game) -> Bool {
        (try? Legendary.getInstalledGames().contains(game)) ?? false || (LocalGames.library?.contains(game) ?? false)
    }
    
    private func sortGames(_ games: [Game]) -> [Game] {
        games.sorted { game1, game2 in
            if game1.isFavourited != game2.isFavourited {
                return game1.isFavourited && !game2.isFavourited
            }
            if let installedGames = try? Legendary.getInstalledGames(),
               installedGames.contains(game1) != installedGames.contains(game2) {
                return installedGames.contains(game1)
            }
            if let localGames = LocalGames.library,
               localGames.contains(game1) != localGames.contains(game2) {
                return localGames.contains(game1)
            }
            return game1.title < game2.title
        }
    }
    
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
            } else {
                switch data.data.libraryDisplayMode {
                case .grid:
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: [.init(.adaptive(minimum: 335))]) {
                            ForEach(games) { game in
                                GameCard(game: .constant(game))
                                    .padding([.leading, .vertical])
                            }
                        }
                        .searchable(text: $searchString, placement: .toolbar)
                    }
                case .list:
                    List {
                        ForEach(games) { game in
                            GameListRow(game: .constant(game))
                        }
                    }
                    .searchable(text: $searchString, placement: .toolbar)
                }
            }
        }
    }
}

#Preview {
    GameListEvo(filterOptions: .constant(.init()))
        .environmentObject(NetworkMonitor())
}
