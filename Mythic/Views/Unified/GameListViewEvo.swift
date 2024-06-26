import Foundation
import SwiftUI

struct GameListEvo: View {
    @State private var searchString: String = .init()
    @State private var refresh: Bool = false
    @State private var isGameImportViewPresented: Bool = false
    @State private var filterOptions: FilterOptions = .init()
    @AppStorage("isGameListLayoutEnabled") private var isListLayoutEnabled: Bool = false

    struct FilterOptions {
        var showInstalled: Bool = false
        var platform: Platform = .all
        var source: GameSource = .all
    }
    
    enum Platform: String, CaseIterable {
        case all = "All"
        case mac = "macOS"
        case windows = "Windows®"
    }
    
    enum GameSource: String, CaseIterable {
        case all = "All"
        case epic = "Epic"
        case steam = "Steam"
        case local = "Local"
    }
    
    private var games: [Game] {
        let filteredGames = filterGames(unifiedGames)
        return sortGames(filteredGames)
    }
    
    private func filterGames(_ games: [Game]) -> [Game] {
        games.filter { game in
            let matchesSearch = searchString.isEmpty || game.title.localizedCaseInsensitiveContains(searchString)
            let matchesInstalled = !filterOptions.showInstalled || isGameInstalled(game)
            let matchesPlatform = filterOptions.platform == .all || game.platform?.rawValue == filterOptions.platform.rawValue
            let matchesSource = filterOptions.source == .all || game.type.rawValue == filterOptions.source.rawValue
            
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
            filterBar
            
            if !unifiedGames.isEmpty {
                if isListLayoutEnabled {
                    List {
                        ForEach(games) { game in
                            GameListRow(game: .constant(game))
                        }
                    }
                    .searchable(text: $searchString, placement: .toolbar)
                } else {
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: [.init(.adaptive(minimum: 335))]) {
                            ForEach(games) { game in
                                GameCard(game: .constant(game))
                                    .padding([.leading, .vertical])
                            }
                        }
                        .searchable(text: $searchString, placement: .toolbar)
                    }
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
    
    private var filterBar: some View {
        HStack {
            Toggle("Installed", isOn: $filterOptions.showInstalled)
            
            Picker("Platform", selection: $filterOptions.platform) {
                ForEach(Platform.allCases, id: \.self) { platform in
                    Text(platform.rawValue).tag(platform)
                }
            }
            
            Picker("Source", selection: $filterOptions.source) {
                ForEach(GameSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            
            Spacer()
            
            Button {
                isListLayoutEnabled.toggle()
            } label: {
                Image(systemName: isListLayoutEnabled ? "square.grid.2x2" : "list.bullet")
            }
        }
        .padding()
    }
}

#Preview {
    GameListEvo()
        .environmentObject(NetworkMonitor())
}
