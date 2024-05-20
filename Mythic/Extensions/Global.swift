//
//  Global.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI
import OSLog
import UserNotifications
import SwordRPC

// MARK: - Global Constants
/// A simpler alias of `FileManager.default`.
let files: FileManager = .default

/// A simpler alias of `UserDefaults.standard`.
let defaults: UserDefaults = .standard

/// A simpler alias of `workspace`.
let workspace: NSWorkspace = .shared

let notifications: UNUserNotificationCenter = .current()

let mainLock: NSRecursiveLock = .init()

let discordRPC: SwordRPC = .init(appId: "1191343317749870712") // Mythic's discord application ID

var unifiedGames: [Game] { (LocalGames.library ?? []) + ((try? Legendary.getInstallable()) ?? []) }


struct UnknownError: LocalizedError {
    var errorDescription: String? = "An unknown error occurred."
}

// MARK: - Enumerations
/// Enumeration containing the two different game platforms available.
enum GamePlatform: String, CaseIterable, Codable, Hashable {
    case macOS = "macOS"
    case windows = "Windows®"
}

enum GameType: String, CaseIterable, Codable, Hashable {
    case epic = "Epic"
    case local = "Local"
}

class Game: ObservableObject, Hashable, Codable, Identifiable, Equatable {
    // MARK: Stubs
    static func == (lhs: Game, rhs: Game) -> Bool {
        return lhs.type == rhs.type &&
        lhs.title == rhs.title &&
        lhs.id == rhs.id &&
        lhs.platform == rhs.platform &&
        lhs.imageURL == rhs.imageURL &&
        lhs.path == rhs.path
    }
    
    // MARK: Hash
    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(title)
        hasher.combine(id)
        hasher.combine(platform)
        hasher.combine(imageURL)
        hasher.combine(wideImageURL)
        hasher.combine(path)
    }
    
    // MARK: Initializer
    init(type: GameType, title: String, id: String? = nil, platform: GamePlatform? = nil, imageURL: URL? = nil, wideImageURL: URL? = nil, path: String? = nil) {
        self.type = type
        self.title = title
        self.id = id ?? UUID().uuidString
        self.platform = platform
        self.imageURL = imageURL
        self.wideImageURL = wideImageURL
        self.path = path
    }
    
    // MARK: Mutables
    var type: GameType
    var title: String
    var id: String
    
    private var _platform: GamePlatform?
    var platform: GamePlatform? {
        get { return _platform ?? (self.type == .epic ? try? Legendary.getGamePlatform(game: self) : nil) }
        set { _platform = newValue }
    }
    
    private var _imageURL: URL?
    var imageURL: URL? {
        get { _imageURL ?? (self.type == .epic ? .init(string: Legendary.getImage(of: self, type: .tall)) : nil) }
        set { _imageURL = newValue }
    }
    
    private var _wideImageURL: URL?
    var wideImageURL: URL? {
        get { _imageURL ?? (self.type == .epic ? .init(string: Legendary.getImage(of: self, type: .normal)) : nil) }
        set { _imageURL = newValue }
    }

    private var _path: String?
    var path: String? {
        get { _path ?? (self.type == .epic ? try? Legendary.getGamePath(game: self) : nil) }
        set { _path = newValue }
    }
    
    // MARK: Properties
    var bottleName: String {
        get {
            let bottleKey: String = id.appending("_defaultBottle")
            
            if Wine.allBottles?[bottleKey] == nil { defaults.removeObject(forKey: bottleKey) }
            defaults.register(defaults: [bottleKey: "Default"]) // reregister after removal
            return defaults.string(forKey: bottleKey)!
        }
        set {
            if Wine.allBottles?[newValue] != nil {
                defaults.set(newValue, forKey: id.appending("_defaultBottle"))
            }
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
    
    // MARK: Functions
    func move(to newLocation: URL) async throws {
        switch type {
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
    // case uninstall = "uninstalling"
}

@available(*, deprecated, renamed: "GameOperation", message: "womp")
@Observable class GameModification: ObservableObject {
    static var shared: GameModification = .init()
    
    var game: Mythic.Game?
    var type: GameModificationType?
    var status: [String: [String: Any]]?
    
    static func reset() {
        DispatchQueue.main.async {
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
            switch GameOperation.shared.current!.game.type {
            case .epic:
                Task(priority: .high) { [weak self] in
                    guard self != nil else { return }
                    do {
                        try await Legendary.install(args: GameOperation.shared.current!, priority: false)
                        try await notifications.add(
                            .init(identifier: UUID().uuidString,
                                  content: {
                                      let content = UNMutableNotificationContent()
                                      content.title = "Finished \(GameOperation.shared.current?.type.rawValue ?? "modifying") \"\(GameOperation.shared.current?.game.title ?? "Unknown")\"."
                                      return content
                                  }(),
                                  trigger: nil)
                        )
                    } catch {
                        try await notifications.add(
                            .init(identifier: UUID().uuidString,
                                  content: {
                                      let content = UNMutableNotificationContent()
                                      content.title = "Error \(GameOperation.shared.current?.type.rawValue ?? "modifying") \"\(GameOperation.shared.current?.game.title ?? "Unknown")\"."
                                      content.body = error.localizedDescription
                                      return content
                                  }(),
                                  trigger: nil)
                        )
                    }
                    
                    DispatchQueue.main.asyncAndWait {
                        GameOperation.shared.current = nil
                    }
                    
                    GameOperation.advance()
                }
            case .local: // this should literally never happen how do you install a local game
                DispatchQueue.main.asyncAndWait {
                    GameOperation.shared.current = nil
                }
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
        shared.status = InstallStatus()
        log.debug("[operation.advance] queuing configuration can advance, no active downloads, game present in queue")
        DispatchQueue.main.async {
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

        GameOperation.log.debug("now monitoring \(gamePlatform.rawValue) game \(game.title)")

        DispatchQueue.main.async {
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
                    workspace.runningApplications.contains(where: { $0.bundleURL?.path == gamePath })
                case .windows:
                    (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep -i '\(gamePath)' | grep -v grep"]))?.isEmpty == false
                }
            }()
            
            if !isRunning {
                DispatchQueue.main.async { GameOperation.shared.runningGames.remove(game) }
                isOpen = false
            } else {
                sleep(3)
            }
            
            GameOperation.log.debug("\(game.title) \(isRunning ? "is still running" : "has been quit" )")
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
        var game: Mythic.Game,
            platform: GamePlatform,
            type: GameModificationType,
            // swiftlint:disable redundant_optional_initialization
            optionalPacks: [String]? = nil,
            baseURL: URL? = nil,
            gameFolder: URL? = nil
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
    init(_ game: Mythic.Game) { self.game = game }
    let game: Mythic.Game
    var errorDescription: String? = "This game doesn't exist."
}

func toggleTitleBar(_ value: Bool) {
    if let window = NSApp.windows.first {
        window.titlebarAppearsTransparent = !value
        window.titleVisibility = value ? .visible : .hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = !value
        window.standardWindowButton(.zoomButton)?.isHidden = !value
        window.isMovableByWindowBackground = !value
    }
}

// MARK: - Functions
// MARK: App Install Checker
/**
 Checks if an app with the given bundle identifier is installed on the system.
 
 - Parameter bundleIdentifier: The bundle identifier of the app.
 - Returns: `true` if the app is installed; otherwise, `false`.
 */
func isAppInstalled(bundleIdentifier: String) -> Bool {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = [
        "bash", "-c",
        "mdfind \"kMDItemCFBundleIdentifier == '\(bundleIdentifier)'\""
    ]
    
    let stdout = Pipe()
    process.standardOutput = stdout
    process.launch()
    
    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? .init()
    
    return !output.isEmpty
}
