import Foundation
import SwiftUI

// temporarily moved during refactor
struct GameListFilterOptions {
    var showInstalled: Bool = false
    var platform: InclusiveGamePlatform = .all
    var source: InclusiveGameSource = .all
}

enum ViewStyle: String, CaseIterable { // TODO: replace isGameListLayoutEnabled
    case grid = "Grid"
    case list = "List"
}

enum InclusiveGamePlatform: String, CaseIterable {
    case all = "All"
    case mac = "macOS"
    case windows = "Windows®"
}

enum InclusiveGameSource: String, CaseIterable {
    case all = "All"
    case epic = "Epic"
    case local = "Local"
}

@Observable final class GameListVM {
    var searchString: String = ""
    var refresh: Bool = false
    var filterOptions: GameListFilterOptions = .init()
    var games: [Game] = []
    
    init() {
        updateGames()
    }
    
    func debouncedUpdateGames() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            if !Task.isCancelled {
                updateGames()
            }
        }
    }
    
    private var debounceTask: Task<Void, Never>?
}

private extension GameListVM {
    func updateGames() {
        let filteredGames = filterGames(unifiedGames)
        games = sortGames(filteredGames)
    }
    
    func filterGames(_ games: [Game]) -> [Game] {
        games.filter { game in
            let matchesSearch = searchString.isEmpty || game.title.localizedCaseInsensitiveContains(searchString)
            let matchesInstalled = !filterOptions.showInstalled || isGameInstalled(game)
            let matchesPlatform = filterOptions.platform == .all || game.platform?.rawValue == filterOptions.platform.rawValue
            let matchesSource = filterOptions.source == .all || game.source.rawValue == filterOptions.source.rawValue
            
            return matchesSearch && matchesInstalled && matchesPlatform && matchesSource
        }
    }
    
    func isGameInstalled(_ game: Game) -> Bool {
        (try? Legendary.getInstalledGames().contains(game)) ?? false || (LocalGames.library?.contains(game) ?? false)
    }
    
    func sortGames(_ games: [Game]) -> [Game] {
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
}
