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
            GameListViewModel.shared.libraryUpdateProgress = nil
        }

        // if variadics are empty, default to all cases
        let storefronts = storefronts.isEmpty ? Game.Storefront.allCases : storefronts as [Game.Storefront]

        // One storefront failing must not stop the others. Legendary throws NotSignedInError whenever
        // there is no Epic account, and it used to abort the whole refresh -- so a user signed in to
        // Steam but not Epic would never see their Steam library at all. Failures are collected and the
        // first is rethrown once every requested storefront has had its turn.
        var failures: [Error] = .init()

        if storefronts.contains(.epicGames) {
            do {
                try mergeIntoLibrary(installables: try Legendary.getInstallableGames(),
                                     installed: try Legendary.getInstalledGames())
            } catch {
                log.error("Unable to refresh game data from Epic Games: \(error.localizedDescription)")
                failures.append(error)
            }
        }

        if storefronts.contains(.steam) {
            do {
                // The owned-library enumeration is what makes getInstallableGames() non-empty. It is
                // rate-limited internally by a cache lifetime, so calling it on every refresh is cheap
                // after the first, and a failure here must not cost us the installed titles below.
                if Steam.isSignedIn {
                    do {
                        try await Steam.refreshOwnedGames { stage in
                            Task { @MainActor in
                                GameListViewModel.shared.libraryUpdateProgress = .init(for: stage)
                            }
                        }
                    } catch {
                        log.error("Unable to enumerate the Steam library: \(error.localizedDescription)")
                    }
                }

                // Installed titles come from their on-disk manifests, so they surface even when the
                // SteamCMD session has lapsed.
                try mergeIntoLibrary(installables: Steam.isSignedIn ? try Steam.getInstallableGames() : [],
                                     installed: try Steam.getInstalledGames())
            } catch {
                log.error("Unable to refresh game data from Steam: \(error.localizedDescription)")
                failures.append(error)
            }
        }

        if let firstFailure = failures.first { throw firstFailure }
    }

    /// Shared merge step: installables that aren't installed are added outright, installed titles are
    /// merged into any existing instance rather than overwriting it.
    private func mergeIntoLibrary(installables: [some Game], installed: [some Game]) throws {
        for game in installables where !installed.contains(where: { $0 == game }) {
            library.update(with: game)
        }

        for fetchedGame in installed {
            if let existing = library.first(where: { $0 == fetchedGame }) {
                try existing.merge(with: fetchedGame, requiring: .identicalIgnoredKeys)
                library.update(with: existing)
            } else {
                library.update(with: fetchedGame)
            }
        }
    }
}
