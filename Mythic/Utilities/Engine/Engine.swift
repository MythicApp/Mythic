//
//  Engine.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog
import SemanticVersion

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
            let properties = try? await retrieveEngineProperties()
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

    static func retrieveEngineProperties() async throws -> EngineProperties {
        guard isInstalled else { throw NotInstalledError() }

        let decoder: PropertyListDecoder = .init()
        decoder.semanticVersionDecodingStrategy = .defaultCodable

        let properties = directory.appending(path: "Properties.plist")
        return try decoder.decode(EngineProperties.self, from: .init(contentsOf: properties))
    }

    static func getLatestRelease(for channelName: ReleaseChannel = releaseChannel) async throws -> UpdateCatalog.Release {
        let catalog = try await retrieveUpdateCatalog()

        guard let channel = catalog.channels[channelName],
              let latestRelease = channel.latestRelease else {
            throw UnableToParseChannelError()
        }

        return latestRelease
    }
    
    static func isUpdateAvailable(for channelName: ReleaseChannel = releaseChannel) async throws -> Bool {
        let latestRelease: UpdateCatalog.Release = try await getLatestRelease(for: channelName)
        let properties = try await retrieveEngineProperties()

        return latestRelease.version > properties.version
    }

    static func install() -> AsyncThrowingStream<InstallProgress, Error> {
        AsyncThrowingStream { continuation in
            Task(priority: .high) {
                do {
                    guard !isInstalled else { continuation.finish(); return } // silent exit
                    let release = try await getLatestRelease()

                    let task = URLSession.shared.downloadTask(with: URL(string: release.downloadURL)!) { file, response, error in
                        guard error == nil else { continuation.finish(throwing: error!); return }
                        if let httpResponse = response as? HTTPURLResponse,
                           !(200...299).contains(httpResponse.statusCode) {
                            continuation.finish(throwing: URLError(.badServerResponse)); return
                        }
                        guard let file = file else {
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
                                
                                // FIXME: swift compiler bug? 'type of expression is ambiguous without a type annotation on line 110?
                                // FIXME: this is not good, tar errors won't propagate
                                let processResult = try? await process.runWrapped()

                                // `man tar` (bsdtar) — The tar utility exits 0 on success, and >0 if an error occurs.
                                guard processResult?.exitCode == 0 else {
                                    log.error("unable to install engine, tar stderr: \(process.standardError)")
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

