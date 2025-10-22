//
//  GameListEvoVM.swift
//  Mythic
//
//  Created by Marcus Ziade on ~23/06/24.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI

@MainActor
final class GameListVM: ObservableObject {
    static let shared: GameListVM = .init()

    struct FilterOptions {
        var showInstalled: Bool = false
        var platform: Game.InclusivePlatform = .all
        var source: Game.InclusiveSource = .all
    }

    enum ViewStyle: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
    }

    @Published var searchString: String = "" {
        didSet {
            debouncedUpdateGames()
        }
    }

    var refreshFlag: Bool = false
    @Published var filterOptions: FilterOptions = .init() {
        didSet {
            Task { @MainActor in
                updateGames()
            }
        }
    }

    @Published var games: [Game] = []
    private var debounceTask: Task<Void, Never>?
    private var installedGamesCache: Set<Game> = []
    private var isSorted = false

    private init() {
        Task { @MainActor in
            updateGames()
        }
    }

    private func debouncedUpdateGames() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled {
                updateGames()
            }
        }
    }

    func refresh() {
        VariableManager.shared.setVariable("isUpdatingLibrary", value: true)
        withAnimation {
            self.refreshFlag.toggle()
        }
        VariableManager.shared.setVariable("isUpdatingLibrary", value: false)
    }
}

private extension GameListVM {
    @MainActor
    func updateGames() {
        let filteredGames = filterGames(unifiedGames)

        withAnimation {
            if isSorted || games != filteredGames {
                games = sortGames(filteredGames)
                isSorted = true
            } else {
                games = filteredGames
            }
        }
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
        if installedGamesCache.isEmpty {
            if let installedGames = try? Legendary.getInstalledGames() {
                installedGamesCache = Set(installedGames)
            }
        }
        return installedGamesCache.contains(game) || (LocalGames.library?.contains(game) ?? false)
    }

    func sortGames(_ games: [Game]) -> [Game] {
        games.sorted {
            // compare favourites
            if $0.isFavourited != $1.isFavourited {
                return $0.isFavourited // favorited games come first
            }

            // compare installation status
            let isInstalled0 = isGameInstalled($0)
            let isInstalled1 = isGameInstalled($1)
            if isInstalled0 != isInstalled1 {
                return isInstalled0 // installed games come first
            }

            // compare titles
            return $0.title < $1.title // sort by title alphabetically
        }
    }
}
