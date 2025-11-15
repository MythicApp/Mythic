//
//  Game.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 13/6/2024.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import Combine
import OSLog
import UserNotifications
import SwordRPC
import SwiftUI

// FIXME: this function should not be needed, ideally.
// TODO: find all non-preview that uses this function and prevent that from happening.
func placeholderGame(forSource source: LegacyGame.Source,
                     forPlatform platform: LegacyGame.Platform = .windows) -> LegacyGame {
    switch source {
    case .epic:
        return .init(id: .init(), title: "MRAAAHHH", source: source, platform: platform)
    case .local:
        return .init(title: "GROAAARR", source: source, platform: platform)
    }
}

@available(*, deprecated, message: "Replaced by polymorphic Game")
final class LegacyGame: ObservableObject, Identifiable, @unchecked Sendable {
    // TODO: FOR ME TO READ LATER;
    // TODO: polymorphism
    // THE PLAN IS TO HAVE A 'GAMES' SET OF LOCAL AND EPIC AND OTHER GAMES
    // IN USERDEFAULTS, THAT INITIALLY STORED PROPERTIES AS A CACHE
    // REDUCING THE NEED FOR ME TO STORE DATA IN A SEPARATE ARRAY (PersistentGameData)
    // TODO: LIST
    // - MIGRATOR FOR SEPARATED VARIABLES
    // - CODING KEYS FOR OLD VALUES IN SEPARATE EXTENSION

    init(id: String? = nil,
         title: String,
         source: Source,
         platform: Platform,
         location: URL? = nil,
         imageURL: URL? = nil,
         wideImageURL: URL? = nil,
         containerURL: URL? = nil) /* throws */ {
        /*
        guard !(source == .epic && id == nil) else {
            throw CocoaError(.featureUnsupported)
        }
         */

        self.id = id ?? UUID().uuidString
        self.title = title
        self.source = source
        self._platform = platform
        self._location = location

        if let imageURL = imageURL {
            self.imageURL = imageURL
        } else if case .epic = source,
                  let url = Legendary.getImageURL(of: self, type: .tall) {
            self.imageURL = .init(string: url)
        }

        if let wideImageURL = wideImageURL {
            self.wideImageURL = wideImageURL
        } else if case .epic = source,
                  let url = Legendary.getImageURL(of: self, type: .normal) {
            self.wideImageURL = .init(string: url)
        }

        self.containerURL = containerURL ?? Wine.containerURLs.first
    }

    // MARK: Mutables
    var id: String
    var title: String
    var source: Source

    private var _platform: Platform
    private var _location: URL?

    var imageURL: URL?
    var wideImageURL: URL?

    var containerURL: URL?
    var launchArguments: [String] = .init()

    var isFavourited: Bool = false

    var platform: Platform {
        get {
            if case .epic = source,
               let fetchedPlatform = try? Legendary.getGamePlatform(game: self),
               _platform != fetchedPlatform {
                _platform = fetchedPlatform
            }

            return _platform
        }
        set { _platform = newValue }
    }

    var location: URL? {
        get {
            if case .epic = source,
               let fetchedPath = try? Legendary.getGamePath(game: self),
               _location?.path != fetchedPath {
                _location = .init(filePath: fetchedPath)
            }

            return _location
        }
        set { _location = newValue }
    }

    var isFallbackImageAvailable: Bool {
        switch platform {
        case .macOS:
            do {} // TODO: see `GameCard.FallbackImageCard`
        case .windows:
            do {} // TODO: implmement ms portable executable, and get image that way
        }

        // for now, this is the only way a fallback will be available
        return (platform == .macOS) // FIXME: stub
    }

    var isInstalled: Bool {
        switch self.source {
        case .epic:
            let games = try? Legendary.getInstalledGames()
            return (games?.contains(self) == true)
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

    @MainActor var isInstalling: Bool {
        LegacyGameOperation.shared.current?.game == self
    }
    @MainActor var isQueuedForInstalling: Bool {
        LegacyGameOperation.shared.queue.contains(where: { $0.game == self })
    }
    @MainActor var isLaunching: Bool {
        LegacyGameOperation.shared.launching == self
    }

    // MARK: Functions
    func move(to newLocation: URL) async throws {
        guard files.isWritableFile(atPath: newLocation.path) else {
            throw CocoaError(.fileWriteUnknown)
        }

        switch source {
        case .epic:
            try await Legendary.move(game: self, newPath: newLocation.path(percentEncoded: false))

            // confirm that the game actually moved, otherwise we have unhandled behaviour.
            guard let retrievedNewPath = try Legendary.getGamePath(game: self) else {
                throw CocoaError(.fileWriteUnknown)
            }

            location = .init(filePath: retrievedNewPath)
        case .local:
            guard let location = self.location else {
                throw CocoaError(.fileNoSuchFile)
            }

            try files.moveItem(at: location, to: newLocation)
            self.location = newLocation
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
}

extension LegacyGame: Equatable {
    static func == (lhs: LegacyGame, rhs: LegacyGame) -> Bool {
        return lhs.id == rhs.id
    }
}

extension LegacyGame: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension LegacyGame: Codable {
}

extension LegacyGame {
    enum ImageType {
        case vertical
        case horizontal
        case custom(URL)
    }

    /// Enumeration containing the two different game platforms available.
    enum Platform: String, CaseIterable, Codable, Hashable {
        case macOS = "macOS"
        case windows = "Windows®"
    }
    
    /// Enumeration containing all available game sources (storefronts).
    enum Source: String, CaseIterable, Codable, Hashable {
        case epic = "Epic Games"
        case local = "Local" // TODO: remove this explicitly, rename parent enum to 'Storefront', cases epic, steam, etc
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
        case runnable = "The game launches and you are able to play, but some game features are nonfunctional."
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

@available(*, deprecated, renamed: "LegacyGameOperation", message: "womp")
@Observable class GameModification: ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) static var shared: GameModification = .init()
    
    var game: Mythic.LegacyGame?
    var type: GameModificationType?
    var status: [String: [String: Any]]?
    
    static func reset() {
        Task { @MainActor in
            shared.game = nil
            shared.type = nil
            shared.status = nil
        }
    }
    
    var launching: LegacyGame? // no other place bruh
}

class LegacyGameOperation: ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) static var shared: LegacyGameOperation = .init()
    
    internal static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "LegacyGameOperation"
    )
    
    // swiftlint:disable:next implicit_optional_initialization
    @Published var current: InstallArguments? = nil {
        didSet {
            guard LegacyGameOperation.shared.current != oldValue, LegacyGameOperation.shared.current != nil else { return }
            switch LegacyGameOperation.shared.current!.game.source {
            case .epic:
                guard let current = LegacyGameOperation.shared.current else { return }
                let gameTitle = current.game.title
                let type = current.type.rawValue
                
                Task(priority: .high) {
                    do {
                        try await Legendary.install(arguments: current, priority: false)
                        
                        try? await notifications.add(
                            .init(identifier: UUID().uuidString,
                                  content: {
                                      let content = UNMutableNotificationContent()
                                      content.title = String(localized: "Finished \(type) \"\(gameTitle)\".",
                                                             comment: "")
                                      return content
                                  }(),
                                  trigger: nil)
                        )
                    } catch {
                        Task { @MainActor in
                            let alert = NSAlert()

                            alert.messageText = "Error \(LegacyGameOperation.shared.current?.type.rawValue ?? "modifying") \"\(LegacyGameOperation.shared.current?.game.title ?? "Unknown")\"." // cannot localise raw values
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: String(localized: "OK"))

                            if let window = NSApp.windows.first {
                                alert.beginSheetModal(for: window)
                            }
                        }
                    }
                    
                    DispatchQueue.main.asyncAndWait {
                        LegacyGameOperation.shared.current = nil
                    }
                    
                    LegacyGameOperation.advance()
                }
            case .local:
                LegacyGameOperation.advance()
            }
        }
    }
    
    @Published var status: LegacyGameOperation.InstallStatus = .init()
    
    @Published var queue: [InstallArguments] = .init() {
        didSet { LegacyGameOperation.advance() }
    }
    
    static func advance() {
        log.debug("[operation.advance] attempting operation advancement")
        guard shared.current == nil, let first = shared.queue.first else { return }
        Task {
            await MainActor.run {
                shared.status = InstallStatus()
            }
        }
        log.debug("[operation.advance] queuing configuration can advance, no active downloads, game present in queue")
        Task {
            await MainActor.run {
                shared.current = first; shared.queue.removeFirst()
                log.debug("[operation.advance] queuing configuration advanced. current game will now begin installation. (\(shared.current!.game.title))")
            }
        }
    }
    
    @Published var runningGameIDs: Set<String> = .init()
    
    internal static func isGameRunning(_ game: LegacyGame) -> Bool {
        guard let location = game.location else { return false }
        switch game.platform {
        case .macOS:
            return workspace.runningApplications.contains(where: { $0.bundleURL == location })
        case .windows:
            // hacky but functional
            let result = try? Process.execute(
                executableURL: .init(filePath: "/bin/bash"),
                arguments: [
                    "-c",
                    "ps aux | grep -i '\(location.path)' | grep -v grep"
                ]
            )
            return (result?.standardOutput.isEmpty == false)
        }
    }
    
    // Wait until the game process appears (or timeout). Returns true if detected.
    private static func awaitGameLaunch(for game: LegacyGame) async -> Bool {
        for _ in 0..<15 {
            if isGameRunning(game) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }
    
    private func attemptToMonitor(game: LegacyGame) async {
        LegacyGameOperation.log.debug("Preparing to monitor game \"\(game.title)\"")
        
        let started = await LegacyGameOperation.awaitGameLaunch(for: game)
        
        // clear the launching val once awaitGameLaunch completed
        await MainActor.run {
            withAnimation {
                LegacyGameOperation.shared.launching = nil
            }
        }
        
        guard started else {
            LegacyGameOperation.log.debug("Game \"\(game.title)\" did not appear to start; skipping monitor.")
            return
        }
        
        if defaults.bool(forKey: "minimiseOnGameLaunch") {
            await MainActor.run {
                NSApp.windows.first?.miniaturize(nil)
            }
        }
        
        LegacyGameOperation.log.debug("Now monitoring \(game.platform.rawValue) game \"\(game.title)\"")

        Task {
            await MainActor.run {
                LegacyGameOperation.shared.runningGameIDs.insert(game.id)
            }
        }
        
        discordRPC.setPresence({
            var presence = RichPresence()
            presence.details = "Playing a \(game.platform.rawValue) game."
            presence.state = "Playing \(game.title)"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())
        
        while true {
            LegacyGameOperation.log.debug("checking if \"\(game.title)\" is still running")
            if !LegacyGameOperation.isGameRunning(game) {
                break
            }
            try? await Task.sleep(for: .seconds(3))
        }
        
        Task {
            await MainActor.run {
                LegacyGameOperation.shared.runningGameIDs.remove(game.id)
            }
        }
        
        discordRPC.setPresence({
            var presence = RichPresence()
            presence.details = "Just finished playing \(game.title)"
            presence.state = "Idle"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())
        
        LegacyGameOperation.log.debug("\"\(game.title)\" has been quit")
    }

    // swiftlint:disable:next implicit_optional_initialization
    @MainActor @Published var launching: LegacyGame? = nil {
        didSet {
            // When a game is set, start a monitor that waits for start, clears launching, then tracks until exit.
            if let game = launching {
                Task(priority: .background) { await attemptToMonitor(game: game) }
            }
        }
    }
    
    struct InstallArguments: Equatable, Hashable {
        var game: Mythic.LegacyGame
        
        /// The target installation's platform.
        var platform: Mythic.LegacyGame.Platform
        
        /// The nature of the game modification.
        var type: GameModificationType
        
        // swiftlint:disable implicit_optional_initialization
        /// (Legendary) packs to install along with the base game.
        var optionalPacks: [String]? = nil
        
        /// Custom ``URL`` for the game to install to.
        var baseURL: URL? = nil
        
        /// The absolute folder where the game should be installed to.
        var gameFolder: URL? = nil
        // swiftlint:enable implicit_optional_initialization
    }
    
    struct InstallStatus {
        // swiftlint:disable nesting
        struct Progress {
            var percentage: Double
            var downloadedObjects: Int?
            var totalObjects: Int?
            var runtime: String?
            var eta: String?
        }
        
        struct Download {
            var downloaded: Double?
            var written: Double?
        }
        
        struct Cache {
            var usage: Double?
            var activeTasks: Int?
        }
        
        struct DownloadSpeed {
            var raw: Double?
            var decompressed: Double?
        }
        
        struct DiskSpeed {
            var write: Double?
            var read: Double?
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
    init(_ game: Mythic.LegacyGame) {
        self.game = game
    }
    
    let game: Mythic.LegacyGame
    var errorDescription: String? { String(localized: "The game \"\(game.title)\" doesn't exist.") }
}
