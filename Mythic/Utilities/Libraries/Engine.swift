//
//  Libraries.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import ZIPFoundation
import SemanticVersion // https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
import CryptoKit
import SwiftyJSON
import OSLog
import UserNotifications

// MARK: - Libraries Class
/// Manages the installation, removal, and versioning of Mythic's libraries. (Mythic Engine)
class Libraries {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Libraries"
    )
    
    /// The directory where Mythic Engine is installed.
    static let directory = Bundle.appHome!.appending(path: "Libraries")
    
    private static let dataLock = NSLock()
    
    static func
    
    // MARK: - isInstalled Method
    /**
     Checks if Mythic Engine is installed.
     
     - Returns: `true` if installed, `false` otherwise.
     */
    static func isInstalled() -> Bool {
        guard files.fileExists(atPath: directory.path) else { return false }
        // defaults.register(defaults: ["engineChecksum": checksum!])
        return true // defaults.string(forKey: "engineChecksum") == checksum
    }
    
    // MARK: - getVersion Method
    /** Gets the version of the installed Mythic Engine.
     
     - Returns: The semantic version of the installed libraries.
     */
    static func getVersion() -> SemanticVersion? {
        guard isInstalled() else { return nil }
        
        guard
            let versionData = try? Data(contentsOf: directory.appending(path: "version.plist")),
            let version = try? PropertyListDecoder().decode([String: SemanticVersion].self, from: versionData)["version"]
        else {
            log.error("Unable to get installed GPTK version")
            return nil
        }
        
        return version
    }
    
    // MARK: - fetchLatestVersion Method
    /**
     Fetches the latest version of Mythic Engine.
     
     - Returns: The semantic version of the latest libraries.
     */
    static func fetchLatestVersion() -> SemanticVersion? {
        guard let currentVersion = getVersion() else {
            return nil
        }
        
        let session = URLSession(configuration: .default)
        let group = DispatchGroup()
        var latestVersion: SemanticVersion = currentVersion
        
        group.enter()
        session.dataTask(
            with: URL(string: "https://raw.githubusercontent.com/MythicApp/GPTKBuilder/main/version.plist")!
        ) { (data, _, error) in
            defer { group.leave() }
            
            guard error == nil else {
                log.error("Unable to check for new GPTK version: \(error?.localizedDescription ?? "Unknown Error.")")
                return
            }
            
            guard let data = data else {
                return
            }
            
            do {
                latestVersion = try PropertyListDecoder().decode([String: SemanticVersion].self, from: data)["version"] ?? latestVersion
            } catch {
                log.error("Unable to decode upstream GPTK version.")
            }
        }
        .resume()
        group.wait()
        
        return latestVersion
    }
    
    // MARK: - Remove Method
    /**
     Removes Mythic Engine.
     
     - Parameter completion: A closure to be called upon completion of the removal.
     */
    static func remove() throws {
        defer { dataLock.unlock() }
        guard isInstalled() else { throw NotInstalledError() }
        
        dataLock.lock()
        try files.removeItem(at: directory)
    }
}
