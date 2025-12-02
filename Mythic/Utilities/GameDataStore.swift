//
//  GameDataStore.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 2/12/2025.
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
    
    var library: Set<Game> = .init() {
        didSet {
            gamesObserver.setValue(library.map({ AnyGame($0) }),
                                   forKey: "games")
        }
    }

    @MainActor private init() {
        // initialize observer with default empty array
        let initialGames: [AnyGame] = (try? defaults.decodeAndGet([AnyGame].self, forKey: "games")) ?? []
        
        gamesObserver = CodableUserDefaultsObserver(
            key: "games",
            defaultValue: [],
            store: .standard,
            initialValue: initialGames
        )
        
        // load library on initialisation
        library = Set(gamesObserver.value.map({ $0.base }))
        
        // observe external changes
        gamesObserver.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            let newLibrary = Set(self.gamesObserver.value.map({ $0.base }))
            if newLibrary != self.library {
                self.log.debug("Games key changed externally, reloading library")
                self.library = newLibrary
            }
        }.store(in: &cancellables)
    }
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    var recent: Game? {
        guard !Game.store.library.allSatisfy({ $0.lastLaunched == nil }) else { return nil }

        return Game.store.library.max {
            $0.lastLaunched ?? .distantPast < $1.lastLaunched ?? .distantPast
        }
    }

    func refreshFromStorefronts() async throws {
        GameListViewModel.shared.isUpdatingLibrary = true
        defer {
            GameListViewModel.shared.isUpdatingLibrary = false
        }
        
        // legendary (epic games)
        do {
            let installables = try Legendary.getInstallableGames()
            let installed = try Legendary.getInstalledGames()
            
            // add installables that aren't installed
            for game in installables where !installed.contains(where: { $0 == game }) {
                library.update(with: game)
            }
            
            // installed: merge instead of overwrite
            for installedGame in installed {
                var updatedGame: Game = installedGame
                if let existing = library.first(where: { $0 == installedGame }) {
                    existing.merge(with: installedGame)
                    updatedGame = existing
                }
                
                library.update(with: updatedGame)
            }
        } catch {
            log.error("Unable to refresh game data from Epic Games: \(error.localizedDescription)")
            throw error
        }
    }
}
