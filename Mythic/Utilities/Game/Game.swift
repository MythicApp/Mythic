//
//  Game.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

// TODO: migrate favouriteGames
// TODO: update GameOperation to GameDispatch, fix implementation to be less convoluted

class Game: Identifiable {
    let id: String
    let title: String
    let platform: Platform

    // use underlying variable
    // swiftlint:disable:next identifier_name
    var _location: URL?

    var verticalImageURL: URL?
    var horizontalImageURL: URL?

    var containerURL: URL?

    var launchArguments: [String] = []
    var isFavourited: Bool = false

    init(id: String,
         title: String,
         platform: Platform,
         location: URL?,
         containerURL: URL? = nil) {
        self.id = id
        self.title = title
        self.platform = platform
        self._location = location

        self.containerURL = containerURL ?? Wine.containerURLs.first
    }

    var isInstalled: Bool { false }                 // override in subclass
    var needsVerification: Bool? { nil }            // override in subclass

    final var isFallbackImageAvailable: Bool {
        switch platform {
        case .macOS:
            return false // FIXME: stub
        case .windows:
            return false // FIXME: stub
        }
    }

    /* FIXME: TODO: uncomment
    @MainActor var isInstalling: Bool {
        GameOperation.shared.current?.game == self
    }
    @MainActor var isQueuedForInstalling: Bool {
        GameOperation.shared.queue.contains(where: { $0.game == self })
    }
    @MainActor var isLaunching: Bool {
        GameOperation.shared.launching == self
    }
     */

    // MARK: Actions
    @MainActor
    func launch() async throws {
        fatalError("Subclasses must implement launch()")
    }

    func move(to newLocation: URL) async throws {
        fatalError("Subclasses must implement move(to:)")
    }
}

extension Game: Equatable {
    static func == (lhs: Game, rhs: Game) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Game: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
