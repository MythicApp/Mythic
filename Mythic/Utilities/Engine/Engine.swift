//
//  Engine.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import OSLog
import SemanticVersion
import AppKit

final class Engine {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Engine"
    )
    
    // long ahh code
    static var releaseChannel: ReleaseChannel {
        get {
            UserDefaults.standard.register(defaults: ["engineChannel": ReleaseChannel.stable.rawValue])
            if let channelString = UserDefaults.standard.string(forKey: "engineChannel"),
               let channel: ReleaseChannel = .init(rawValue: channelString) {
                return channel
            }
            
            return .stable
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "engineChannel")
        }
    }
    
    static let directory = Bundle.appHome!.appending(path: "Engine")
    static let wineExecutableURL = directory.appending(path: "wine/bin/wine64")
    
    // TODO: use checksum to verify?
    // sum generated using `shasum` of the actual tarfile
    // shasum -a Engine-2.6.0.tar.xz | awk '{print $1}' > Engine-2.6.0.tar.xz.sha256
    // from now on, you must create 'directory' manually
    // tar -cJf Engine.tar.xz -C Engine . (archive w/o folder)
    
    // TODO: + add sum URL to test updatestream
    
    static var isInstalled: Bool {
        return FileManager.default.fileExists(atPath: directory.appending(path: "Properties.plist").path)
    }
    
    static var installedVersion: SemanticVersion? {
        get async {
            let properties = try? await retrieveInstallationProperties()
            return properties?.version
        }
    }
    
    static func retrieveUpdateCatalog() async throws -> UpdateCatalog {
        let catalogURL = URL(string: "https://dl.getmythic.app/engine/EngineUpdateStream.plist")!
        let (data, response) = try await URLSession.shared.data(from: catalogURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        
        let decoder: PropertyListDecoder = .init()
        decoder.semanticVersionDecodingStrategy = .semverString
        
        let catalog = try decoder.decode(UpdateCatalog.self, from: data)
        
        if catalog.version != UpdateCatalog.nativeVersion {
            log.warning("""
            UpdateCatalog was parsed, but its version does not match that of the currently implemented version.
            An app update may be necessary.
            """)
        }
        
        return catalog
    }
    
    static func retrieveInstallationProperties() async throws -> InstallationProperties {
        guard isInstalled else { throw NotInstalledError() }
        
        let propertiesFile = directory.appending(path: "Properties.plist")
        return try PropertyListDecoder().decode(InstallationProperties.self, from: .init(contentsOf: propertiesFile))
    }
    
    static func getLatestCompatibleRelease(for channelName: ReleaseChannel = releaseChannel) async throws -> UpdateCatalog.Release {
        let catalog = try await retrieveUpdateCatalog()
        
        guard let channel = catalog.channels[channelName],
              let latestCompatibleRelease = channel.latestCompatibleRelease else {
            throw UnableToRetrieveCompatibleReleaseError()
        }
        
        return latestCompatibleRelease
    }
    
    static func checkIfUpdateAvailable(for channelName: ReleaseChannel = releaseChannel) async throws -> Bool {
        let latestRelease: UpdateCatalog.Release = try await getLatestCompatibleRelease(for: channelName)
        let properties = try await retrieveInstallationProperties()
        
        return latestRelease.version > properties.version
    }
    
    static func install() -> AsyncThrowingStream<InstallProgress, Error> {
        AsyncThrowingStream { continuation in
            Task(priority: .high) {
                do {
                    guard !isInstalled else { continuation.finish(); return } // silent exit
                    let release = try await getLatestCompatibleRelease()
                    
                    let task = URLSession.shared.downloadTask(with: URL(string: release.downloadURL)!) { file, response, error in
                        guard error == nil else { continuation.finish(throwing: error!); return }
                        if let httpResponse = response as? HTTPURLResponse,
                           !(200...299).contains(httpResponse.statusCode) {
                            continuation.finish(throwing: URLError(.badServerResponse)); return
                        }
                        guard let file else {
                            continuation.finish(throwing: CocoaError(.fileNoSuchFile)); return
                        }
                        
                        Task(priority: .userInitiated) {
                            let installationProgress: Progress = .init(totalUnitCount: 100)
                            
                            do {
                                // check for remnant/empty engine folder
                                if (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?.isEmpty == false {
                                    try FileManager.default.removeItem(at: directory)
                                }
                                // create engine directory if necessary
                                if !FileManager.default.fileExists(atPath: directory.path) {
                                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                                }
                                
                                continuation.yield(.init(stage: .installing, progress: installationProgress))
                                
                                let process: Process = .init()
                                process.executableURL = .init(filePath: "/usr/bin/tar")
                                process.arguments = ["-xJf", file.path, "-C", directory.path]
                                
                                let tarResult = try await process.runWrapped()
                                
                                // `man tar` (bsdtar) — The tar utility exits 0 on success, and >0 if an error occurs.
                                
                                guard process.terminationStatus == 0 else {
                                    log.error("""
                                        Engine installation unsuccessful, Tar exited with a nonzero termination status.
                                        Output (stderr): \(tarResult.standardError ?? "N/A")
                                        """)
                                    
                                    // filewriteunknown is more suitable than Process.NonZeroTerminationStatus.
                                    continuation.finish(throwing: CocoaError(.fileWriteUnknown)); return
                                }
                                
                                installationProgress.completedUnitCount = 100
                                continuation.yield(.init(stage: .installing, progress: installationProgress))
                                
                                continuation.finish()
                            } catch {
                                try? FileManager.default.removeItem(atPath: file.path)
                                continuation.finish(throwing: error)
                            }
                        }
                    }
                    
                    Task(priority: .utility) {
                        while case .running = task.state {
                            continuation.yield(InstallProgress(stage: .downloading, progress: task.progress))
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                        // finally yield upon completion
                        continuation.yield(InstallProgress(stage: .downloading, progress: task.progress))
                    }
                    
                    task.resume()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    static func remove() async throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

extension Engine {
    @MainActor
    static func displayUpdateChecker(userInitiated: Bool) async {
        guard let window = NSApp.windows.first else { return }
        
        let isUpdateAvailable: Bool
        do {
            isUpdateAvailable = try await checkIfUpdateAvailable()
        } catch {
            if userInitiated {
                let alert: NSAlert = .init()
                alert.alertStyle = .critical
                alert.messageText = String(localized: "Unable to check for Mythic Engine updates.")
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: String(localized: "OK"))
                
                await alert.beginSheetModal(for: window)
            }
            
            return
        }
        
        guard isUpdateAvailable else {
            if userInitiated {
                let alert: NSAlert = .init()
                alert.alertStyle = .informational
                alert.messageText = String(localized: "No Mythic Engine updates available.")
                alert.informativeText = String(localized: "You're currently on the latest version, \(await installedVersion?.description ?? String(localized: "an unknown version")).")
                alert.addButton(withTitle: String(localized: "OK"))
                
                await alert.beginSheetModal(for: window)
            }
            return
        }
        
        let latestVersion = (try? await getLatestCompatibleRelease())?.version.description ?? String(localized: "Unknown")
        let currentVersion = await installedVersion?.description ?? String(localized: "an unknown version", comment: "Of Mythic Engine")
        
        let updateAlert: NSAlert = .init()
        updateAlert.messageText = String(localized: "Mythic Engine update available.")
        updateAlert.informativeText = String(localized: """
            A new version of Mythic Engine (\(latestVersion)) has released.
            You're currently using \(currentVersion).
            """)
        updateAlert.addButton(withTitle: String(localized: "Update"))
        updateAlert.addButton(withTitle: String(localized: "Cancel"))
        
        let updateResponse = await updateAlert.beginSheetModal(for: window)
        guard case .alertFirstButtonReturn = updateResponse else { return }
        
        let confirmationAlert: NSAlert = .init()
        confirmationAlert.messageText = String(localized: "Are you sure you want to update now?")
        confirmationAlert.informativeText = String(localized: "This will remove the current version of Mythic Engine.") + String(localized: "The latest version will be installed the next time you attempt to launch a Windows® game.")
        confirmationAlert.addButton(withTitle: String(localized: "Update"))
        confirmationAlert.addButton(withTitle: String(localized: "Cancel"))
        
        let confirmationResponse = await confirmationAlert.beginSheetModal(for: window)
        guard case .alertFirstButtonReturn = confirmationResponse else { return }
        
        do {
            try await remove()
            
            let successAlert: NSAlert = .init()
            successAlert.alertStyle = .informational
            successAlert.messageText = String(localized: "Successfully removed Mythic Engine.")
            successAlert.informativeText = String(localized: "The latest version will be installed the next time you attempt to launch a Windows® game.")
            successAlert.addButton(withTitle: String(localized: "OK"))
            
            await successAlert.beginSheetModal(for: window)
        } catch {
            let errorAlert: NSAlert = .init()
            errorAlert.alertStyle = .critical
            errorAlert.messageText = String(localized: "Unable to remove Mythic Engine.")
            errorAlert.informativeText = error.localizedDescription
            errorAlert.addButton(withTitle: String(localized: "OK"))
            
            await errorAlert.beginSheetModal(for: window)
        }
    }
}
