//
//  Engine.swift
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

// MARK: - Engine Class
/// Manages the installation, removal, and versioning of Mythic Engine.
class Engine {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Engine"
    )
    
    private static let lock = NSLock()
    
    /// The directory where Mythic Engine is installed.
    static let directory = Bundle.appHome!.appending(path: "Engine")
    
    /// The file location of Mythic Engine's property list.
    static let properties = try? Data(contentsOf: directory.appending(path: "properties.plist"))
    
    static var exists: Bool {
        guard files.fileExists(atPath: directory.path) else { return false }
        return true
    }
    
    static var version: SemanticVersion? {
        guard exists else { return nil }
        guard let properties = properties,
              let version = try? PropertyListDecoder().decode([String: SemanticVersion].self, from: properties)["version"]
        else {
            log.error("Unable to get installed engine version.")
            return nil
        }
        return version
    }
    
    static func install(downloadHandler: @escaping (Progress) -> Void, installHandler: @escaping (Bool) -> Void) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let download = URLSession.shared.downloadTask(with: .init(string: "https://nightly.link/MythicApp/Engine/workflows/build/7.7/Engine.zip")!) { tempfile, response, error in
                guard error == nil else { continuation.resume(throwing: error!); return }
                guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else { continuation.resume(throwing: URLError(.badServerResponse)); return }
                
                if let tempfile = tempfile {
                    do {
                        installHandler(false)
                        let unzipProgress: Progress = .init()
                        try files.unzipItem(at: tempfile, to: Bundle.appHome!, progress: unzipProgress)
                        if unzipProgress.isFinished {
                            let archive = Bundle.appHome!.appending(path: "Engine.txz")
                            _ = try Process.execute("/usr/bin/tar", arguments: ["-xJf", archive.path(percentEncoded: false), "-C", Bundle.appHome!.path(percentEncoded: false)])
                            try files.removeItem(at: archive)
                        }
                        installHandler(true)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            download.resume() // observer?
            
            Task(priority: .utility) {
                var debounce: Bool = false
                while true {
                    downloadHandler(download.progress)
                    print("engine: download: \(download.progress.fractionCompleted * 100)% complete")
                    try await Task.sleep(nanoseconds: 500000000) // 0.5 s
                    if download.progress.isFinished { if !debounce { debounce = true } else { break } }
                }
            }
            
            continuation.resume()
        }
    }
    
    // MARK: - fetchLatestVersion Method
    /**
     Fetches the latest version of Mythic Engine.
     
     - Returns: The semantic version of the latest libraries.
     */
    static func fetchLatestVersion() -> SemanticVersion? {
        let group = DispatchGroup()
        var latestVersion: SemanticVersion?
        
        let task = URLSession.shared.dataTask(with: .init(string: "https://raw.githubusercontent.com/MythicApp/Engine/7.7/properties.plist")!) { data, _, error in
            defer { group.leave() }
            
            guard error == nil else { log.error("Unable to check for new Engine version: \(error!.localizedDescription)"); return }
            guard let data = data else { log.error("Fetching latest Engine version returned no data"); return }
            
            do {
                latestVersion = try PropertyListDecoder().decode([String: SemanticVersion].self, from: data)["version"]
            } catch {
                log.error("Unable to decode upstream Engine version.")
            }
        }
        
        group.enter()
        task.resume()
        _ = group.wait(timeout: .now() + 2)
        
        return latestVersion
    }
    
    /// Removes Mythic Engine.
    static func remove() throws {
        defer { lock.unlock() }
        guard exists else { throw NotInstalledError() }
        
        lock.lock()
        try files.removeItem(at: directory)
    }
}
