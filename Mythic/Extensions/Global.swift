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

struct UnknownError: LocalizedError {
    var errorDescription: String? = "An unknown error occurred."
}

// MARK: - Enumerations
/// Enumeration containing the two different game platforms available.
enum GamePlatform: String, CaseIterable, Codable {
    case macOS = "macOS"
    case windows = "Windows®"
}

enum GameType: String, CaseIterable, Codable {
    case epic = "Epic"
    case local = "Local"
}

struct Game: Hashable, Codable {
    init(type: GameType, title: String, appName: String, platform: GamePlatform? = nil, imageURL: URL? = nil, path: String? = nil) {
        self.type = type
        self.title = title
        self.appName = appName
        self.platform = (self.type == .epic ? try? Legendary.getGamePlatform(game: self) : nil)
        self.imageURL = (self.type == .epic ? .init(string: Legendary.getImage(of: self, type: .tall)) : nil)
        self.path = (self.type == .epic ? try? Legendary.getGamePath(game: self) : nil)
    }
    
    var type: GameType
    var title: String
    var appName: String = UUID().uuidString
    var platform: GamePlatform?
    var bottleName: String {
        get {
            if let bottleName = defaults.string(forKey: "\(appName)_defaultBottle"),
               Wine.allBottles?[bottleName] != nil {
                return bottleName
            } else {
                defaults.set("Default", forKey: "\(appName)_defaultBottle")
                return "Default"
            }
        }
        set {
            if Wine.allBottles?[newValue] != nil {
                defaults.set(newValue, forKey: "\(appName)_defaultBottle")
            }
        }
    }
    
    var isFavourited: Bool {
        get { favouriteGames.contains(appName) }
        set {
            if newValue {
                favouriteGames.insert(appName)
            } else {
                favouriteGames.remove(appName)
            }
        }
    }
    
    var imageURL: URL?
    var path: String?
    
    mutating func move(to newLocation: URL) async throws {
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

/// Returns the app names of all favourited games.
var favouriteGames: Set<String> {
    get { return Set(defaults.stringArray(forKey: "favouriteGames") ?? .init()) }
    set { defaults.set(Array(newValue), forKey: "favouriteGames") }
}

enum GameModificationType: String {
    case install = "installing"
    case update = "updating"
    case repair = "repairing"
}

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

/// A `Game` object that serves as a placeholder for unwrapping reasons or otherwise
func placeholderGame(type: GameType) -> Game { // this is so stupid
    return .init(type: type, title: .init(), appName: UUID().uuidString, platform: .macOS)
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
