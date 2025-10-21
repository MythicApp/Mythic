//
//  Game.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 13/6/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import Combine
import OSLog
import UserNotifications
import SwordRPC
import SwiftUI

class Game: ObservableObject, Hashable, Codable, Identifiable, Equatable {
    // MARK: Stubs
    static func == (lhs: Game, rhs: Game) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: Initializer
    init(
        source: Source,
        title: String,
        id: String? = nil,
        platform: Platform? = nil,
        imageURL: URL? = nil,
        wideImageURL: URL? = nil,
        path: String? = nil
    ) {
        self.source = source
        self.title = title
        self.id = id ?? UUID().uuidString
        self.platform = platform
        self.imageURL = imageURL
        self.wideImageURL = wideImageURL
        self.path = path
    }
    
    // MARK: Mutables
    var source: Source
    var title: String
    var id: String

    // MARK: Computed Properties
    private var _platform: Platform?
    var platform: Platform? {
        get {
            return _platform ?? {
                switch self.source {
                case .epic:
                    return try? Legendary.getGamePlatform(game: self)
                case .local:
                    return nil
                }
            }()
        }
        set { _platform = newValue }
    }

    var isFallbackImageAvailable: Bool {
        // for now, this is the only way a fallback will be available
        // see `GameCard.FallbackImageCard`
        return source == .local
    }

    private var _imageURL: URL?
    var imageURL: URL? {
        get {
            return _imageURL ?? {
                switch self.source {
                case .epic:
                    return .init(string: Legendary.getImage(of: self, type: .tall)) // TODO: make getimage return URL
                case .local:
                    return nil
                }
            }()
        }
        set { _imageURL = newValue }
    }
    
    private var _wideImageURL: URL?
    var wideImageURL: URL? {
        get {
            return _wideImageURL ?? {
                switch self.source {
                case .epic:
                    return .init(string: Legendary.getImage(of: self, type: .normal)) // TODO: make getimage return URL
                case .local:
                    return nil
                }
            }()
        }
        set { _wideImageURL = newValue }
    }

    private var _path: String?
    var path: String? {
        get {
            return _path ?? {
                switch self.source {
                case .epic:
                    return try? Legendary.getGamePath(game: self)
                case .local:
                    return nil
                }
            }()
        }
        set { _path = newValue }
    }
    
    // MARK: Properties
    var containerURL: URL? {
        get {
            let key: String = id.appending("_containerURL")
            if let url = defaults.url(forKey: key), !Wine.containerExists(at: url) {
                defaults.removeObject(forKey: key)
            }
            
            if defaults.url(forKey: key) == nil {
                defaults.set(Wine.containerURLs.first, forKey: key)
            }

            return defaults.url(forKey: key)
        }
        set {
            let key: String = id.appending("_containerURL")
            guard let newValue = newValue else { defaults.set(nil, forKey: key); return }
            defaults.set(newValue, forKey: key)
        }
    }

    var launchArguments: [String] {
        get {
            let key: String = id.appending("_launchArguments")
            return defaults.array(forKey: key) as? [String] ?? .init()
        }
        set {
            defaults.set(newValue, forKey: id.appending("_launchArguments"))
        }
    }
    
    var isFavourited: Bool {
        get { favouriteGames.contains(id) }
        set {
            if newValue {
                favouriteGames.insert(id)
            } else {
                favouriteGames.remove(id)
            }
        }
    }
    
    var isInstalled: Bool {
        switch self.source {
        case .epic:
            let games = try? Legendary.getInstalledGames()
            return games?.contains(self) == true
        case .local:
            return true
        }
    }

    var needsUpdate: Bool {
        switch self.source {
        case .epic:
            return Legendary.needsUpdate(game: self)
        case .local:
            return false
        }
    }

    var needsVerification: Bool {
        switch self.source {
        case .epic:
            return Legendary.needsVerification(game: self)
        case .local:
            return false
        }
    }

    var isInstalling: Bool { GameOperation.shared.current?.game == self }
    var isQueuedForInstalling: Bool { GameOperation.shared.queue.contains(where: { $0.game == self }) }
    var isLaunching: Bool { GameOperation.shared.launching == self }

    // MARK: Functions
    func move(to newLocation: URL) async throws {
        switch source {
        case .epic:
            try await Legendary.move(game: self, newPath: newLocation.path(percentEncoded: false))
            path = try! Legendary.getGamePath(game: self) // swiftlint:disable:this force_try
        case .local:
            if let oldLocation = path {
                if files.isWritableFile(atPath: newLocation.path(percentEncoded: false)) {
                    try files.moveItem(atPath: oldLocation, toPath: newLocation.path(percentEncoded: false)) // not very good
                } else {
                    throw FileLocations.FileNotModifiableError(nil)
                }
            }
        }
    }

    func launch() async throws {
        switch source {
        case .epic:
            try await Legendary.launch(game: self)
        case .local:
            try await LocalGames.launch(game: self)
        }
    }

    /// Enumeration containing the two different game platforms available.
    enum Platform: String, CaseIterable, Codable, Hashable {
        case macOS = "macOS"
        case windows = "Windows®"
    }

    /// Enumeration containing all available game types.
    enum Source: String, CaseIterable, Codable, Hashable {
        case epic = "Epic Games"
        case local = "Local"
    }

    enum InclusivePlatform: String, CaseIterable {
        case all = "All"
        case macOS = "macOS"
        case windows = "Windows®"
    }

    enum InclusiveSource: String, CaseIterable {
        case all = "All"
        case epic = "Epic Games"
        case local = "Local"
    }

    enum Compatibility: String, CaseIterable {
        case unplayable = "The game doesn't launch."
        case launchable = "The game launches, but you are unable to play."
        case runable = "The game launches and you are able to play, but some game features are nonfunctional."
        case playable = "The game runs well, and is mostly feature-complete."
        case excellent = "The game runs well, and is feature-complete."
    }
}

/// Returns the app names of all favourited games.
var favouriteGames: Set<String> {
    get { return Set(defaults.stringArray(forKey: "favouriteGames") ?? .init()) }
    set { defaults.set(Array(newValue), forKey: "favouriteGames") }
}

enum GameModificationType: String {
    case install = "installing"
    case update = "updating"
    case repair = "repairing"
    // TODO: case uninstall = "uninstalling"
}

@available(*, deprecated, renamed: "GameOperation", message: "womp")
@Observable class GameModification: ObservableObject {
    static var shared: GameModification = .init()
    
    var game: Mythic.Game?
    var type: GameModificationType?
    var status: [String: [String: Any]]?
    
    static func reset() {
        Task { @MainActor in
            shared.game = nil
            shared.type = nil
            shared.status = nil
        }
    }
    
    var launching: Game? // no other place bruh
}

class GameOperation: ObservableObject {
    static var shared: GameOperation = .init()
    
    internal static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "GameOperation"
    )
    
    // swiftlint:disable:next redundant_optional_initialization
    @Published var current: InstallArguments? = nil {
        didSet {
            // @ObservedObject var operation: GameOperation = .shared
            guard GameOperation.shared.current != oldValue, GameOperation.shared.current != nil else { return }
            switch GameOperation.shared.current!.game.source {
            case .epic:
                Task(priority: .high) { [weak self] in
                    guard self != nil else { return }
                    do {
                        try await Legendary.install(args: GameOperation.shared.current!, priority: false)
                        try? await notifications.add(
                            .init(identifier: UUID().uuidString,
                                  content: {
                                      let content = UNMutableNotificationContent()
                                      content.title = "Finished \(GameOperation.shared.current?.type.rawValue ?? "modifying") \"\(GameOperation.shared.current?.game.title ?? "Unknown")\"."
                                      return content
                                  }(),
                                  trigger: nil)
                        )
                    } catch {
                        Task { @MainActor in
                            let alert = NSAlert()
                            alert.messageText = "Error \(GameOperation.shared.current?.type.rawValue ?? "modifying") \"\(GameOperation.shared.current?.game.title ?? "Unknown")\"."
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            
                            if let window = NSApp.windows.first {
                                alert.beginSheetModal(for: window)
                            }
                        }
                    }
                    
                    DispatchQueue.main.asyncAndWait {
                        GameOperation.shared.current = nil
                    }
                    
                    GameOperation.advance()
                }
            case .local: // this should literally never happen how do you install a local game
                GameOperation.advance()
            }
        }
    }
    
    @Published var status: GameOperation.InstallStatus = .init()
    
    @Published var queue: [InstallArguments] = .init() {
        didSet { GameOperation.advance() }
    }
    
    static func advance() {
        log.debug("[operation.advance] attempting operation advancement")
        guard shared.current == nil, let first = shared.queue.first else { return }
        Task { @MainActor in
            shared.status = InstallStatus()
        }
        log.debug("[operation.advance] queuing configuration can advance, no active downloads, game present in queue")
        Task { @MainActor in
            shared.current = first; shared.queue.removeFirst()
            log.debug("[operation.advance] queuing configuration advanced. current game will now begin installation. (\(shared.current!.game.title))")
        }
    }
    
    @Published var runningGames: Set<Game> = .init()
    
    private func checkIfGameOpen(_ game: Game) async {
        guard let gamePath = game.path, let gamePlatform = game.platform else { return }

        var isOpen = true
        defer {
            discordRPC.setPresence({
                var presence = RichPresence()
                presence.details = "Just finished playing \(game.title)"
                presence.state = "Idle"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                return presence
            }())
        }

        GameOperation.log.debug("Now monitoring \(gamePlatform.rawValue) game \"\(game.title)\"")

        Task { @MainActor in
            GameOperation.shared.runningGames.insert(game)
        }

        discordRPC.setPresence({
            var presence = RichPresence()
            presence.details = "Playing a \(gamePlatform.rawValue) game."
            presence.state = "Playing \(game.title)"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())

        while isOpen {
            GameOperation.log.debug("checking if \"\(game.title)\" is still running")
            
            let isRunning = {
                switch gamePlatform {
                case .macOS:
                    return workspace.runningApplications.contains(where: { $0.bundleURL?.path == gamePath }) // debounce may be necessary because macOS is slow at opening apps
                case .windows: // hacky but functional
                    let result = try? Process.execute(
                        executableURL: .init(fileURLWithPath: "/bin/bash"),
                        arguments: [
                            "-c",
                            "ps aux | grep -i '\(gamePath)' | grep -v grep"
                        ]
                    )

                    return (result?.standardOutput.isEmpty == false)
                }
            }()
            
            if !isRunning {
                Task { @MainActor in
                    GameOperation.shared.runningGames.remove(game)
                }

                isOpen = false
            } else {
                try? await Task.sleep(for: .seconds(3))
            }
            
            GameOperation.log.debug("\"\(game.title)\" \(isRunning ? "is still running" : "has been quit" )")
        }
    }
    
    // swiftlint:disable:next redundant_optional_initialization
    @Published var launching: Game? = nil {
        didSet {
            guard launching == nil, let oldValue = oldValue else { return }
            Task(priority: .background) { await checkIfGameOpen(oldValue) }
        }
    }

    struct InstallArguments: Equatable, Hashable {
        var game: Mythic.Game

        /// The target installation's platform.
        var platform: Mythic.Game.Platform

        /// The nature of the game modification.
        var type: GameModificationType

        // swiftlint:disable redundant_optional_initialization
        /// (Legendary) packs to install along with the base game.
        var optionalPacks: [String]? = nil

        /// Custom ``URL`` for the game to install to.
        var baseURL: URL? = nil

        /// The absolute folder where the game should be installed to.
        var gameFolder: URL? = nil
        // swiftlint:enable redundant_optional_initialization
    }
    
    struct InstallStatus {
        // swiftlint:disable nesting
        struct Progress {
            var percentage: Double
            var downloadedObjects: Int
            var totalObjects: Int
            var runtime: String
            var eta: String
        }
        
        struct Download {
            var downloaded: Double
            var written: Double
        }
        
        struct Cache {
            var usage: Double
            var activeTasks: Int
        }
        
        struct DownloadSpeed {
            var raw: Double
            var decompressed: Double
        }
        
        struct DiskSpeed {
            var write: Double
            var read: Double
        }
        // swiftlint:enable nesting
        
        var progress: Progress?
        var download: Download?
        var cache: Cache?
        var downloadSpeed: DownloadSpeed?
        var diskSpeed: DiskSpeed?
    }
}

/// Your father.
struct GameDoesNotExistError: LocalizedError {
    init(_ game: Mythic.Game) {
        self.game = game
    }

    let game: Mythic.Game
    var errorDescription: String? { "The game \"\(game.title)\" doesn't exist." }
}
