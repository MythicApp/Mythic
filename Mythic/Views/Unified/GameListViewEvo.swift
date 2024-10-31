import Foundation
import SwiftUI

struct GameListEvo: View {
    @StateObject var viewModel: GameListVM = .shared
    @AppStorage("isGameListLayoutEnabled") private var isListLayoutEnabled: Bool = false
    @State private var isGameImportViewPresented: Bool = false
    @ObservedObject private var variables: VariableManager = .shared
    
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
                                .padding([.top, .horizontal])
                        }
                    }
                    .searchable(text: $viewModel.searchString, placement: .toolbar)
                    .onChange(of: viewModel.searchString) { _, _ in
                        viewModel.debouncedUpdateGames()
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHGrid(rows: [.init(.adaptive(minimum: 250))]) {
                        ForEach(viewModel.games) { game in
                            GameCard(game: .constant(game))
                                .padding([.leading, .vertical])
                        }
                    }
                    .searchable(text: $viewModel.searchString, placement: .toolbar)
                    .onChange(of: viewModel.searchString) { _, _ in
                        viewModel.debouncedUpdateGames()
                    }
                }
            }
        }
        .id(viewModel.refreshFlag)
    }
}

#Preview {
    GameListEvo()
        .environmentObject(NetworkMonitor())
}
