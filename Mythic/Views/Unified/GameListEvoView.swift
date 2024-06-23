import SwiftUI

struct GameListEvo: View {
    @State private var viewModel = GameListVM()
    @State private var isGameImportViewPresented: Bool = false
    @State private var filterOptions: FilterOptions = .init()
    @State private var isListView: Bool = false

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
    
    var body: some View {
        VStack {
            filterBar
            
            if !unifiedGames.isEmpty {
                if isListView {
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
                emptyStateView
            }
        }
        .searchable(text: $viewModel.searchString, placement: .toolbar)
        .onChange(of: viewModel.searchString) { _, _ in
            viewModel.debouncedUpdateGames()
        }
    }
}

private extension GameListEvo {
    
    var filterBar: some View {
        HStack {
            Toggle("Installed", isOn: $viewModel.filterOptions.showInstalled)
            
            Picker("Platform", selection: $viewModel.filterOptions.platform) {
                ForEach(Platform.allCases, id: \.self) { platform in
                    Text(platform.rawValue).tag(platform)
                }
            }
            
            Picker("Source", selection: $viewModel.filterOptions.source) {
                ForEach(GameSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }

            Spacer()

            Button {
                isListView.toggle()
            } label: {
                Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
            }
        }
        .padding()
    }
    
    var gameList: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [.init(.adaptive(minimum: 335))]) {
                ForEach(viewModel.games) { game in
                    GameCard(game: .constant(game))
                        .padding([.leading, .vertical])
                }
            }
        }
    }
    
    var emptyStateView: some View {
        VStack {
            Text("No games can be shown.")
                .font(.bold(.title)())
            importGameButton
        }
    }
    
    var importGameButton: some View {
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

#Preview {
    GameListEvo()
        .environmentObject(NetworkMonitor())
}
