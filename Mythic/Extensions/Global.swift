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

// MARK: - Global Constants
/// A simpler alias of `FileManager.default`.
let files: FileManager = .default

/// A simpler alias of `UserDefaults.standard`.
let defaults: UserDefaults = .standard

/// A simpler alias of `workspace`.
let workspace: NSWorkspace = .shared

let notifications: UNUserNotificationCenter = .current()

let gameImageURLCache: URLCache = .init(memoryCapacity: 192_000_000, diskCapacity: 500_000_000) // in bytes

let mainLock: NSRecursiveLock = .init()

var launching: Game?

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
    var type: GameType
    var title: String
    var appName: String = UUID().uuidString
    // var defaultBottle: Wine.Bottle? = Wine.allBottles?["Default"] // TODO: should be appstorage
    var platform: GamePlatform?
    var bottleName: String {
        get {
            if let bottleName = defaults.string(forKey: "\(self.appName)_defaultBottle"),
               Wine.allBottles?[bottleName] != nil {
                return bottleName
            } else {
                defaults.set("Default", forKey: "\(self.appName)_defaultBottle")
                return "Default"
            }
        }
        set {
            if Wine.allBottles?[newValue] != nil {
                defaults.set(newValue, forKey: "\(self.appName)_defaultBottle")
            }
        }
    }
    
    var imageURL: URL?
    var path: String?
}

enum GameModificationType: String {
    case install = "installing"
    case update = "updating"
    case repair = "repairing"
}

class GameModification: ObservableObject {
    static var shared: GameModification = .init()
    
    @Published var game: Mythic.Game?
    @Published var type: GameModificationType?
    @Published var status: [String: [String: Any]]?
    
    static func reset() {
        DispatchQueue.main.sync {
            shared.game = nil
            shared.type = nil
            shared.status = nil
        }
    }
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
