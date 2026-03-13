//
//  GameDataStore.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 2/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import Combine
import OSLog

// TODO: eventually, migrate to SwiftData.
@Observable @MainActor final class GameDataStore {
    static let shared: GameDataStore = .init()
    let log: Logger = .custom(category: "GameDataStore")
    
    private let gamesObserver: CodableUserDefaultsObserver<[AnyGame]>
    private var isUpdatingFromObserver = false
    
    var library: Set<Game> = .init() {
        didSet {
            guard !isUpdatingFromObserver else { return }
            try? UserDefaults.standard.encodeAndSet(library.map({ AnyGame($0) }), forKey: "games")
        }
    }

    @MainActor private init() {
        // initialise observer
        gamesObserver = .init(key: "games",
                              defaultValue: [])
        
        // load library on initialisation
        library = Set(gamesObserver.value.map({ $0.base }))
        
        // observe external changes
        gamesObserver.$value
            .sink { [weak self] newGames in
                guard let self else { return }
                let newLibrary = Set(newGames.map({ $0.base }))
                
                guard newLibrary != self.library else { return }
                self.log.debug("Games key changed in UserDefaults, updating library")
                
                self.isUpdatingFromObserver = true
                defer { self.isUpdatingFromObserver = false }
                self.library = newLibrary
            }
            .store(in: &cancellables)
    }
    
    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = .init()

    var recent: Game? {
        guard !library.allSatisfy({ $0.lastLaunched == nil }) else { return nil }

        return library.max {
            $0.lastLaunched ?? .distantPast < $1.lastLaunched ?? .distantPast
        }
    }

    func refreshFromStorefronts(_ storefronts: Game.Storefront...) async throws {
        GameListViewModel.shared.isUpdatingLibrary = true
        defer {
            GameListViewModel.shared.isUpdatingLibrary = false
        }
        
        // if variadics are empty, default to all cases
        let storefronts = storefronts.isEmpty ? Game.Storefront.allCases : storefronts as [Game.Storefront]
        
        // legendary (epic games)
        if storefronts.contains(.epicGames) {
            do {
                let installables = try Legendary.getInstallableGames()
                let installed = try Legendary.getInstalledGames()
                
                // add installables that aren't installed
                for game in installables where !installed.contains(where: { $0 == game }) {
                    library.update(with: game)
                }
                
                try mergeInstalledGames(installed)
            } catch {
                log.error("Unable to refresh game data from Epic Games: \(error.localizedDescription)")
                throw error
            }
        }
        
        if storefronts.contains(.steam) {
            do {
                let sources = steamSourcesToRefresh()
                guard !sources.isEmpty else {
                    log.debug("Skipping Steam refresh because no Steam library metadata is available.")
                    return
                }
    
                var installed: [SteamGame] = []
                for source in sources {
                    installed += try Steam.getInstalledGames(in: source.rootURL, containerURL: source.containerURL)
                }
    
                try reconcileSteamInstalledGames(installed)
            } catch let error as Steam.Error {
                switch error {
                case .defaultRootUnavailable, .missingLibraryFoldersFile:
                    log.debug("Skipping Steam refresh because no Steam library metadata is available.")
                default:
                    log.error("Unable to refresh game data from Steam: \(error.localizedDescription)")
                    throw error
                }
            } catch {
                log.error("Unable to refresh game data from Steam: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    private func mergeInstalledGames<S: Sequence>(_ fetchedGames: S) throws where S.Element: Game {
        for fetchedGame in fetchedGames {
            if let existing = library.first(where: { $0 == fetchedGame }) {
                try existing.merge(with: fetchedGame, requiring: .identicalIgnoredKeys)
                library.update(with: existing)
            } else {
                library.update(with: fetchedGame)
            }
        }
    }
    
    private func steamSourcesToRefresh() -> [SteamGame.InstallationSource] {
        var sources: [SteamGame.InstallationSource] = []
    
        if let steamRootURL = Steam.rootURL,
           Steam.containsLibraryMetadata(in: steamRootURL) {
            sources.append(.init(rootURL: steamRootURL.standardizedFileURL, containerURL: nil))
        }
    
        for game in library.compactMap({ $0 as? SteamGame }) {
            guard let installationSource = game.installationSource, !sources.contains(installationSource) else { continue }
            sources.append(installationSource)
        }
    
        return sources
    }
    
    private func upsertSteamGames(_ fetchedGames: [SteamGame]) throws {
        for fetchedGame in fetchedGames {
            if let existing = library.first(where: { $0 == fetchedGame }) as? SteamGame {
                try existing.merge(with: fetchedGame, requiring: .identicalIgnoredKeys)
                existing.steamInstallationRootURL = fetchedGame.steamInstallationRootURL
                existing._containerURL = fetchedGame._containerURL
                library.update(with: existing)
            } else {
                library.update(with: fetchedGame)
            }
        }
    }
    
    private func reconcileSteamInstalledGames(_ fetchedGames: [SteamGame]) throws {
        try upsertSteamGames(fetchedGames)
    
        // Steam support currently models only discovered installed titles. After a
        // successful manifest refresh, any Steam entry missing from the current app
        // manifest set is stale and should be removed rather than left pretending to
        // reflect current installation state.
        let fetchedIDs = Set(fetchedGames.map(\.id))
        library = Set(library.filter { game in
            guard game is SteamGame else { return true }
            return fetchedIDs.contains(game.id)
        })
    }

}
