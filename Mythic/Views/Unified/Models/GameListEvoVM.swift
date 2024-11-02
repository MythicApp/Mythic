//
//  GameListEvoVM.swift
//  Mythic
//
//  Created by Marcus Ziade on ~23/06/24.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI

@Observable final class GameListVM: ObservableObject {
    static let shared: GameListVM = .init()

    struct FilterOptions {
        var showInstalled: Bool = false
        var platform: Game.InclusivePlatform = .all
        var source: Game.InclusiveSource = .all
    }

    enum ViewStyle: String, CaseIterable { // TODO: replace isGameListLayoutEnabled
        case grid = "Grid"
        case list = "List"
    }

    var searchString: String = .init()
    var refreshFlag: Bool = false
    var filterOptions: FilterOptions = .init()
    var games: [Game] = .init()

    private init() {
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

    func refresh() {
        VariableManager.shared.setVariable("isUpdatingLibrary", value: true)
        withAnimation {
            self.refreshFlag.toggle()
        }
        VariableManager.shared.setVariable("isUpdatingLibrary", value: false)
    }
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
