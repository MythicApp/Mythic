//
//  Engine.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

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
final class Engine {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Engine"
    )
    
    static let currentStream: String = defaults.string(forKey: "engineBranch") ?? Stream.stable.rawValue
    
    private static let lock = NSLock() // unused
    
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
    
    static func install(downloadHandler: @escaping (Progress) -> Void, installHandler: @escaping (Bool) -> Void) async throws { // Future?
        return try await withCheckedThrowingContinuation { continuation in
            let download = URLSession.shared.downloadTask(with: .init(string: "https://nightly.link/MythicApp/Engine/workflows/build/\(currentStream)/Engine.zip")!) { tempfile, response, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode else { continuation.resume(throwing: URLError(.badServerResponse)); return }
                
                if let tempfile = tempfile {
                    do {
                        installHandler(false)
                        let unzipProgress: Progress = .init()
                        try files.unzipItem(at: tempfile, to: Bundle.appHome!, progress: unzipProgress)
                        if unzipProgress.isFinished {
                            let archive = Bundle.appHome!.appending(path: "Engine.txz")
                            _ = try Process.execute("/usr/bin/tar", arguments: ["-xJf", archive.path(percentEncoded: false), "-C", Bundle.appHome!.path(percentEncoded: false)])
                            try? files.removeItem(at: archive)
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
                    log.debug("[engine] [download] \(download.progress.fractionCompleted * 100)% complete")
                    try await Task.sleep(for: .seconds(0.5))
                    if download.progress.isFinished { if !debounce { debounce = true } else { break } }
                }
            }
        }
    }
    
    // MARK: - fetchLatestVersion Method
    /**
     Fetches the latest version of Mythic Engine.
     
     - Returns: The semantic version of the latest libraries.
     */
    static func fetchLatestVersion(stream: Stream = .init(rawValue: currentStream) ?? .stable) -> SemanticVersion? {
        let group = DispatchGroup()
        var latestVersion: SemanticVersion?
        
        let task = URLSession.shared.dataTask(with: .init(string: "https://raw.githubusercontent.com/MythicApp/Engine/\(stream.rawValue)/properties.plist")!) { data, _, error in
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
        
        group.wait()
        
        return latestVersion
    }
    
    static func isLatestVersionReadyForDownload(stream: Stream = .init(rawValue: currentStream) ?? .stable) -> Bool? {
        let group = DispatchGroup()
        var result: Bool?
        
        let task = URLSession.shared.dataTask(with: .init(string: "https://api.github.com/repos/MythicApp/Engine/actions/runs")!) { data, _, error in
            defer { group.leave() }
            
            guard error == nil else { log.error("Unable to connect to GitHub API, cannot verify if Mythic Engine is ready for download: \(error!.localizedDescription)"); return }
            guard let data = data else { log.error("GitHub API returned nil data, unable to verify if Mythic Engine is ready for download."); return }
            
            do {
                let json = try JSON(data: data)
                let runs = json["workflow_runs"]
                
                func isSuccessfulRun(_ run: (key: String, value: JSON)) -> Bool {
                    guard let branch = run.1["head_branch"].string,
                          let status = run.1["status"].string,
                          let conclusion = run.1["conclusion"].string else {
                        return false
                    }
                    return branch == stream.rawValue && status == "completed" && conclusion == "success"
                }
                
                let recent = runs.first(where: isSuccessfulRun)
                result = (recent != nil)
            } catch {
                log.error("Unable to verify if Engine has finished cloud-compilation: \(error.localizedDescription)")
            }

        }
        
        group.enter()
        task.resume()
        
        group.wait()
        
        return result
    }
    
    static func needsUpdate() -> Bool? {
        guard let latestVersion = fetchLatestVersion(),
              let currentVersion = version
        else {
            return nil
        }
        return latestVersion > currentVersion
    }
    
    /// Removes Mythic Engine.
    static func remove() throws {
        defer { lock.unlock() }
        guard exists else { throw NotInstalledError() }
        
        lock.lock()
        try files.removeItem(at: directory)
    }
}
