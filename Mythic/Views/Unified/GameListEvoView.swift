import SwiftUI

struct GameListEvo: View {
    @State private var viewModel = GameListVM()
    @State private var isGameImportViewPresented: Bool = false
    
    var body: some View {
        VStack {
            filterBar
            
            if !unifiedGames.isEmpty {
                gameList
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
