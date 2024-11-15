//
//  Global.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftUI
import UserNotifications
import SwordRPC

// MARK: - Global Constants
/// A simpler alias of `FileManager.default`.
let files: FileManager = .default

/// A simpler alias of `UserDefaults.standard`.
let defaults: UserDefaults = .standard

/// A simpler alias of `NSWorkspace.shared`.
let workspace: NSWorkspace = .shared

/// A simpler alias of `NSApp[lication].shared`.
let sharedApp: NSApplication = .shared

let notifications: UNUserNotificationCenter = .current()

let mainLock: NSRecursiveLock = .init()

let discordRPC: SwordRPC = .init(appId: "1191343317749870712") // Mythic's discord application ID

var unifiedGames: [Game] { (LocalGames.library ?? []) + ((try? Legendary.getInstallable()) ?? []) }

struct UnknownError: LocalizedError {
    var errorDescription: String? = "An unknown error occurred."
}

// MARK: - Functions
// MARK: App Install Checker
/**
 Checks if an app with the given bundle identifier is installed on the system.
 
 - Parameter bundleIdentifier: The bundle identifier of the app.
 - Returns: `true` if the app is installed; otherwise, `false`.
 */
func isAppInstalled(bundleIdentifier: String) -> Bool {
    let process: Process = .init()
    process.launchPath = "/usr/bin/env"
    process.arguments = [
        "bash", "-c",
        "mdfind \"kMDItemCFBundleIdentifier == '\(bundleIdentifier)'\""
    ]
    
    let stdout: Pipe = .init()
    process.standardOutput = stdout
    process.launch()
    
    let data: Data = stdout.fileHandleForReading.readDataToEndOfFile()
    let output: String = .init(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    
    return !output.isEmpty
}
