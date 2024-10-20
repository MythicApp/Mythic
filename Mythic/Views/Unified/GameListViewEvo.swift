import Foundation
import SwiftUI

struct GameListEvo: View {
    @StateObject var viewModel: GameListVM = .shared
    @AppStorage("isGameListLayoutEnabled") private var isListLayoutEnabled: Bool = false
    @State private var isGameImportViewPresented: Bool = false

    private var games: [Game] {
        let filteredGames = filterGames(unifiedGames)
        return sortGames(filteredGames)
    }

    private func filterGames(_ games: [Game]) -> [Game] {
        games.filter { game in
            let matchesSearch = viewModel.searchString.isEmpty || game.title.localizedCaseInsensitiveContains(viewModel.searchString)
            let matchesInstalled = !viewModel.filterOptions.showInstalled || isGameInstalled(game)
            let matchesPlatform = viewModel.filterOptions.platform == .all || game.platform?.rawValue == viewModel.filterOptions.platform.rawValue
            let matchesSource = viewModel.filterOptions.source == .all || game.source.rawValue == viewModel.filterOptions.source.rawValue

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
            } else if isListLayoutEnabled {
                ScrollView(.vertical) {
                    LazyVStack {
                        ForEach(games) { game in
                            GameListCard(game: .constant(game))
                                .padding([.top, .horizontal])
                        }
                    }
                    .searchable(text: $viewModel.searchString, placement: .toolbar)
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHGrid(rows: [.init(.adaptive(minimum: 250))]) {
                        ForEach(games) { game in
                            GameCard(game: .constant(game))
                                .padding([.leading, .vertical])
                        }
                    }
                    .searchable(text: $viewModel.searchString, placement: .toolbar)
                }
            }
        }
    }
}

#Preview {
    GameListEvo()
        .environmentObject(NetworkMonitor())
}
