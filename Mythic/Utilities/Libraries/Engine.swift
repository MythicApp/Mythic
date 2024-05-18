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
    
    /// The directory where Mythic Engine is installed.
    static let directory = Bundle.appHome!.appending(path: "Engine")
    static let properties = try? Data(contentsOf: directory.appending(path: "properties.plist"))
    
    private static let dataLock = NSLock()
    
    static var exists: Bool {
        guard files.fileExists(atPath: directory.path) else { return false }
        return true
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
            
            download.resume()
            
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
    
    // MARK: - getVersion Method
    /** Gets the version of the installed Mythic Engine.
     
     - Returns: The installed Mythic Engine version.
     */
    static func getVersion() -> SemanticVersion? {
        guard exists else { return nil }
        
        guard
            let properties = properties,
            let version = try? PropertyListDecoder().decode([String: SemanticVersion].self, from: properties)["version"]
        else {
            log.error("Unable to get installed Engine version")
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
        guard exists else { throw NotInstalledError() }
        
        dataLock.lock()
        try files.removeItem(at: directory)
    }
}
