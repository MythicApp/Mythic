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
    
    var library: [Game] {
        Game.store.library
            .sorted(by: { a, _ in a.isOperating }) // swiftlint:disable:this identifier_name
            .sorted(by: { $0.title < $1.title })
            .sorted(by: { $0.installationState > $1.installationState })
            .filter({ searchString.isEmpty ? true : $0.title.localizedStandardContains(searchString) })
    }

    private var sortOptions: [SortOptions] = [.favorite, .installed, .title]
    private let logger: Logger = .custom(category: "GameListViewModel")
    
    var isUpdatingLibrary: Bool = false
}

extension GameListViewModel {
    struct FilterOptions: Equatable, Sendable {
        var showInstalled: Bool = false
        var platform: Game.Platform? = .none
        var storefront: Game.Storefront? = .none
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
