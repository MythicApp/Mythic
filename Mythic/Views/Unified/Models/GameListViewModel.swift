//
//  GameListViewModel.swift
//  Mythic
//
//  Created by Marcus Ziade on ~23/06/24.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
final class GameListViewModel: ObservableObject {
    static let shared: GameListViewModel = .init()

    struct FilterOptions: Equatable, Sendable {
        var showInstalled: Bool = false
        var platform: Game.InclusivePlatform = .all
        var source: Game.InclusiveSource = .all
    }

    enum Layout: String, CaseIterable, Sendable, Codable {
        case grid = "Grid"
        case list = "List"
    }

    enum SortCriteria: CaseIterable, Sendable {
        case favorite
        case installed
        case title
    }

    @Published var searchString: String = .init()
    @Published var filterOptions: FilterOptions = .init()
    @Published var games: [Game] = []
    @Published var refreshFlag: Bool = false

    private var cancellables: Set<AnyCancellable> = .init()
    private let installedGamesCache: InstalledGamesCache = .init()
    private var sortCriteria: [SortCriteria] = [.favorite, .installed, .title]
    private let debounceInterval: TimeInterval = 0.3
    private let logger: Logger = .custom(category: "GameListViewModel")

    private init() {
        setupBindings()
        updateGames()
    }

    /// Refreshes the game list and invalidates the installed games cache
    func refresh() {
        VariableManager.shared.setVariable("isUpdatingLibrary", value: true)

        Task(priority: .userInitiated) {
            await installedGamesCache.invalidate()

            withAnimation {
                refreshFlag.toggle()
            }
            updateGames()

            VariableManager.shared.setVariable("isUpdatingLibrary", value: false)
        }
    }

    /// Updates the sort criteria and refreshes the game list
    func setSortCriteria(_ criteria: [SortCriteria]) {
        sortCriteria = criteria
        updateGames()
    }
}

private extension GameListViewModel {
    func setupBindings() {
        $searchString
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateGames()
            }
            .store(in: &cancellables)

        $filterOptions
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateGames()
            }
            .store(in: &cancellables)
    }

    func updateGames() {
        Task(priority: .userInitiated) {
            let filtered: [Game] = await filterGames(unifiedGames)
            let sorted: [Game] = await sortGames(filtered)

            withAnimation {
                games = sorted
            }
        }
    }

    func filterGames(_ games: [Game]) async -> [Game] {
        let searchString: String = self.searchString
        let filterOptions: FilterOptions = self.filterOptions
        let cache: InstalledGamesCache = self.installedGamesCache

        struct IndexedGame: Sendable {
            let index: Int
            let game: Game
        }

        return await withTaskGroup(of: IndexedGame?.self) { group in
            for (index, game) in games.enumerated() {
                group.addTask {
                    let matchesSearch: Bool = searchString.isEmpty || game.title.localizedCaseInsensitiveContains(searchString)

                    let isInstalled: Bool = await cache.isInstalled(game)
                    let matchesInstalled: Bool = !filterOptions.showInstalled || isInstalled

                    let matchesPlatform: Bool = filterOptions.platform == .all || game.platform?.rawValue == filterOptions.platform.rawValue
                    let matchesSource: Bool = filterOptions.source == .all || game.source.rawValue == filterOptions.source.rawValue

                    let passes: Bool = matchesSearch && matchesInstalled && matchesPlatform && matchesSource
                    return passes ? .init(index: index, game: game) : nil
                }
            }

            var filtered: [IndexedGame] = []
            for await result in group {
                if let result {
                    filtered.append(result)
                }
            }
            return filtered.sorted { $0.index < $1.index }.map(\.game)
        }
    }

    func sortGames(_ games: [Game]) async -> [Game] {
        let sortCriteria: [SortCriteria] = self.sortCriteria
        let cache: InstalledGamesCache = self.installedGamesCache

        struct GameMetadata: Sendable {
            let game: Game
            let isFavorited: Bool
            let isInstalled: Bool
        }

        var gamesWithMetadata: [GameMetadata] = []

        for game in games {
            let isInstalled: Bool = await cache.isInstalled(game)
            gamesWithMetadata.append(.init(game: game, isFavorited: game.isFavourited, isInstalled: isInstalled))
        }

        return gamesWithMetadata.sorted { lhs, rhs in
            for criterion in sortCriteria {
                let comparison: ComparisonResult

                switch criterion {
                case .favorite:
                    if lhs.isFavorited == rhs.isFavorited {
                        comparison = .orderedSame
                    } else {
                        comparison = lhs.isFavorited ? .orderedAscending : .orderedDescending
                    }

                case .installed:
                    if lhs.isInstalled == rhs.isInstalled {
                        comparison = .orderedSame
                    } else {
                        comparison = lhs.isInstalled ? .orderedAscending : .orderedDescending
                    }

                case .title:
                    comparison = lhs.game.title.localizedStandardCompare(rhs.game.title)
                }

                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            }
            return false
        }.map(\.game)
    }
}

actor InstalledGamesCache {
    private var cache: Set<Game>?

    /// Checks if a game is installed
    func isInstalled(_ game: Game) -> Bool {
        if cache == nil {
            refreshCache()
        }

        return cache?.contains(game) ?? false || (LocalGames.library?.contains(game) ?? false)
    }

    /// Invalidates the cache, forcing a refresh on next access
    func invalidate() {
        cache = nil
    }

    private func refreshCache() {
        cache = (try? Legendary.getInstalledGames()).map(Set.init) ?? []
    }
}
