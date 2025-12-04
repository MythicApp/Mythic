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

@Observable @MainActor final class GameListViewModel {
    static let shared: GameListViewModel = .init()

    var searchString: String = .init()
    var searchTokens: [SearchToken] = [] {
        didSet {
            let platforms: [SearchToken] = searchTokens.compactMap { if case .platform = $0 { $0 } else { nil } }
            let storefronts: [SearchToken] = searchTokens.compactMap { if case .storefront = $0 { $0 } else { nil } }
            let installations: [SearchToken] = searchTokens.filter { $0 == .installed || $0 == .notInstalled }
            
            if platforms.count > 1, let last = platforms.last {
                searchTokens.removeAll { if case .platform = $0 { $0 != last } else { false } }
            }
            if storefronts.count > 1, let last = storefronts.last {
                searchTokens.removeAll { if case .storefront = $0 { $0 != last } else { false } }
            }
            if installations.count > 1, let last = installations.last {
                searchTokens.removeAll { ($0 == .installed || $0 == .notInstalled) && $0 != last }
            }
        }
    }
    
    var sortedLibrary: [Game] {
        GameDataStore.shared.library
            .sorted(by: { $0.title < $1.title })                            // primary sort — title
            .sorted(by: { $0.installationState > $1.installationState })    // secondary sort — installation state
            .sorted(by: { $0.isOperating && !$1.isOperating })              // tertiary sort — operating games
            .filter { game in
                let matchesText: Bool = searchString.isEmpty || game.title.localizedStandardContains(searchString)
                let matchesTokens: Bool = searchTokens.isEmpty || searchTokens.allSatisfy { token in
                    switch token {
                    case .platform(let platform):
                        guard case .installed(_, let gamePlatform) = game.installationState else { return false }
                        return gamePlatform == platform
                    case .storefront(let storefront):
                        return game.storefront == storefront
                    case .installed:
                        if case .installed = game.installationState { return true }
                        return false
                    case .notInstalled:
                        if case .uninstalled = game.installationState { return true }
                        return false
                    case .favourited:
                        return game.isFavourited
                    }
                }
                return matchesText && matchesTokens
            }
    }
    
    var suggestedTokens: [SearchToken] {
        var suggestions: [SearchToken] = []
        
        let hasPlatform: Bool = searchTokens.contains { if case .platform = $0 { true } else { false } }
        let hasStorefront: Bool = searchTokens.contains { if case .storefront = $0 { true } else { false } }
        let hasInstallation: Bool = searchTokens.contains { $0 == .installed || $0 == .notInstalled }
        
        if !hasPlatform { suggestions.append(contentsOf: Game.Platform.allCases.map { .platform($0) }) }
        if !hasStorefront { suggestions.append(contentsOf: Game.Storefront.allCases.map { .storefront($0) }) }
        if !hasInstallation { suggestions += [.installed, .notInstalled] }
        if !searchTokens.contains(.favourited) { suggestions.append(.favourited) }
        
        return suggestions
    }

    private var sortOptions: [SortOptions] = [.favorite, .installed, .title]
    private let logger: Logger = .custom(category: "GameListViewModel")
    
    var isUpdatingLibrary: Bool = false
}

extension GameListViewModel {
    enum SearchToken: Identifiable, Hashable {
        case platform(Game.Platform)
        case storefront(Game.Storefront)
        case installed
        case notInstalled
        case favourited
        
        var id: String {
            switch self {
            case .platform(let platform):
                return "platform_\(platform.description)"
            case .storefront(let storefront):
                return "storefront_\(storefront.description)"
            case .installed:
                return "installed"
            case .notInstalled:
                return "notInstalled"
            case .favourited:
                return "favourited"
            }
        }
    }
    
    struct FilterOptions: OptionSet, Sendable {
        let rawValue: Int
        
        static let installed: FilterOptions = .init(rawValue: 1 << 0)
        static let favourited: FilterOptions = .init(rawValue: 1 << 1)
        
        static let all: FilterOptions = [.installed, .favourited]
    }

    enum Layout: String, CaseIterable, Sendable, Codable, Equatable {
        case grid = "Grid"
        case list = "List"
    }

    enum SortOptions: CaseIterable, Sendable {
        case favorite
        case installed
        case title
    }
}
