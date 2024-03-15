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
    
    // MARK: - Checksum Method
    /**
     Calculates the checksum of the libraries folder and its contents.
     
     - Returns: An integer representing the checksum.
     */
    @available(*, message: "Unused due to inconsistencies")
    static var checksum: String? {
        guard _checksum == nil || _checksum?.isEmpty == true else { return _checksum! }
        
        let group: DispatchGroup = .init()
        let queue: DispatchQueue = .init(label: "checksum", attributes: .concurrent)
        let serialQueue: DispatchQueue = .init(label: "checksumSerial")
        
        var hash: SHA256 = .init()
        guard let enumerator = files.enumerator(atPath: directory.path) else { return nil }
        
        for case let fileName as String in enumerator {
            queue.async(group: group) {
                do {
                    try calculateChecksum(for: directory.appending(path: fileName), hash: &hash)
                } catch {
                    print("checksum: error: \(error.localizedDescription)")
                    serialQueue.async {
                        _checksum = nil
                    }
                }
            }
        }
        
        group.notify(queue: serialQueue) {
            _checksum = hash.finalize().map { String(format: "%02x", $0) }.joined()
        }
        
        group.wait()
        return _checksum
    }
    
    static var _checksum: String? // swiftlint:disable:this identifier_name
    
    private static func calculateChecksum(for directory: URL, hash: inout SHA256) throws {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
        
        let contents = try files.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )
        
        for url in contents {
            guard let isDirectory = try url.resourceValues(forKeys: resourceKeys).isDirectory else { continue }
            
            if isDirectory {
                try calculateChecksum(for: url, hash: &hash)
            } else {
                hash.update(data: try Data(contentsOf: url))
            }
        }
    }
    
    // MARK: - Install Method
    /**
     Installs the Mythic Engine.
     
     - Parameters:
     - downloadProgressHandler: A closure to handle the download progress.
     - installProgressHandler: A closure to handle the installation progress.
     - completion: A closure to be called upon completion of the installation.
     */
    static func install(
        downloadProgressHandler: @escaping (Double) -> Void,
        installProgressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard !isInstalled() else {
            completion(.failure(AlreadyInstalledError()))
            return
        }
        
        let session = URLSession(configuration: .default)
        let installProgress = Progress(totalUnitCount: 100)
        let group = DispatchGroup()
        
        var latestArtifact: [String: Any]?
        
        group.enter()
        session.dataTask(with: URL(string: "https://api.github.com/repos/MythicApp/Engine/actions/artifacts")!) { (data, _, error) in
            defer { group.leave() }
            
            guard error == nil else {
                Logger.network.error("Error retrieving latest GPTK build data: \(error!)")
                completion(.failure(error!))
                return
            }
            
            dataLock.lock()
            defer { dataLock.unlock() }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let artifacts = json["artifacts"] as? [[String: Any]], // FIXME: NOTE: get the latest artifact from MAIN ONLY; NO BRANCHES
               let artifact = artifacts.first {
                latestArtifact = artifact
            }
        }.resume()
        
        group.wait()
        
        let download = session.downloadTask(
            with: URL(string: "https://nightly.link/MythicApp/Engine/workflows/build-gptk/main/Libraries.zip")!
        ) { (file, _, error) in
            guard error == nil else {
                Logger.network.error("Error with GPTK download: \(error!)")
                completion(.failure(error!))
                return
            }
            
            dataLock.lock()
            defer { dataLock.unlock() }
            
            if let file = file {
                Logger.file.notice("Installing libraries...")
                do {
                    try files.unzipItem(at: file, to: directory, progress: installProgress)
                    Logger.file.notice("Finished downloading and installing libraries.")
                } catch {
                    Logger.file.error("Unable to install libraries: \(error.localizedDescription)")
                    do {
                        try files.removeItem(at: file)
                    } catch {
                        Logger.file.error(
                            """
                            Catastophic error, unable to remove libraries download file.
                            Please do this manually by executing [sudo rm -rf \(file)] ")
                            """
                        )
                    }
                    completion(.failure(error))
                }
                
                if files.fileExists(atPath: directory.path) {
                    // defaults.set(checksum, forKey: "librariesChecksum")
                    // Logger.file.notice("Libraries checksum is: \(String(describing: checksum))")
                    completion(.success(true))
                    notifications.add(
                        .init(identifier: UUID().uuidString,
                              content: {
                                  let content = UNMutableNotificationContent()
                                  content.title = "Finished installing Mythic Engine."
                                  content.title = "Windows® games are now playable!"
                                  return content
                              }(),
                              trigger: nil)
                    )
                }
            }
        }
        
        let queue = DispatchQueue(label: "installProgress")
        
        queue.async {
            while !download.progress.isFinished {
                downloadProgressHandler(Double(download.countOfBytesReceived) / (latestArtifact?["size_in_bytes"] as? Double ?? -1))
                log.debug(
                    """
                    download progress:
                    recv \(Double(download.countOfBytesReceived))
                    total: \((latestArtifact?["size_in_bytes"] as? Double ?? -1))
                    """
                )
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            downloadProgressHandler(1.0)
        }
        
        queue.async {
            while !installProgress.isFinished {
                installProgressHandler(installProgress.fractionCompleted)
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            installProgressHandler(1.0)
        }
        
        download.resume()
    }
    
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
    static func remove(completion: @escaping (Result<Bool, Error>) -> Void) { // FIXME: not appropriate use for a completion handler
        defer { dataLock.unlock() }
        
        guard isInstalled() else {
            completion(.failure(NotInstalledError()))
            return
        }
        
        dataLock.lock()
        
        do {
            try files.removeItem(at: directory)
            completion(.success(true))
        } catch {
            Logger.file.error("Unable to remove libraries: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}
