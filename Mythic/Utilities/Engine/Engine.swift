//
//  Engine.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 24/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

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
import SwiftUI

// MARK: - Engine Class
/// Manages the installation, removal, and versioning of Mythic Engine.
final class Engine {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Engine"
    )

    // TODO: refactor in favour of encoding stream object directly
    static let currentStream: String = defaults.string(forKey: "engineBranch") ?? Stream.stable.rawValue

    /// The directory where Mythic Engine is installed.
    static let directory = Bundle.appHome!.appending(path: "Engine")

    private let plistDecoder: PropertyListDecoder = .init()
    static let propertyData = try? Data(contentsOf: directory.appending(path: "properties.plist"))

    static var exists: Bool { files.fileExists(atPath: directory.path) }

    static var version: SemanticVersion? {
        let decoder = PropertyListDecoder()
        if exists,
           let properties = propertyData,
           let decodedProperties = try? decoder.decode([String: SemanticVersion].self, from: properties),
           let version = decodedProperties["version"] {
            return version
        } else {
            log.error("Unable to get installed engine version.")
            return nil
        }
    }

    static func install() -> AsyncThrowingStream<InstallProgress, Error> {
        AsyncThrowingStream { continuation in
            guard workspace.isARM else { continuation.finish(); return }

#if DEBUG
            let sourceURL: URL = .init(string: "http://dl.getmythic.app/engine/artifacts/test_2.6.0.txz.zip")!
#else
            let sourceURL: URL = .init(string: "https://nightly.link/MythicApp/Engine/workflows/build/\(currentStream)/Engine.zip")!
#endif

            let downloadTask = URLSession.shared.downloadTask(with: sourceURL) { downloadedFileURL, response, error in
                if let error = error { continuation.finish(throwing: error); return }
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    continuation.finish(throwing: URLError(.badServerResponse)); return
                }
                guard let downloadedFileURL = downloadedFileURL else {
                    continuation.finish(throwing: URLError(.unknown)); return
                }

                do {
                    let temporaryDirectory = try files.createUniqueTemporaryDirectory()

                    let installationProgress = Progress(totalUnitCount: 100)
                    continuation.yield(.init(stage: .installing, progress: installationProgress))

                    // MARK: unzip
                    let unzipProgress = Progress(totalUnitCount: 100)
                    let unzipObservation = unzipProgress.observe(\.fractionCompleted, options: [.new]) { value, _ in
                        installationProgress.completedUnitCount = Int64(value.fractionCompleted * 50.0)
                        continuation.yield(.init(stage: .installing, progress: installationProgress))
                    }
                    try files.unzipItem(at: downloadedFileURL, to: temporaryDirectory, progress: unzipProgress)
                    try? files.removeItem(at: downloadedFileURL)
                    unzipObservation.invalidate() // release observer, unzip complete

                    // MARK: extraction
                    // within the zipball lies the (tar + xz) file, created by the actual action, called Engine.txz
                    let archive = temporaryDirectory.appending(path: "Engine.txz")

                    // extract the folder within the tarfile to Mythic's home dir using xz decompression
                    Task(priority: .userInitiated) {
                        do {
                            _ = try await Process.execute(
                                executableURL: .init(fileURLWithPath: "/usr/bin/tar"),
                                arguments: ["-xJf", archive.path, "-C", Bundle.appHome!.path]
                            )
                            
                            // mark installationProgress as complete
                            installationProgress.completedUnitCount = 100
                            continuation.yield(.init(stage: .installing, progress: installationProgress))
                            
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            Task(priority: .utility) {
                while true {
                    guard !(downloadTask.progress.isCancelled || downloadTask.progress.isFinished) else {
                        continuation.yield(.init(stage: .downloading, progress: downloadTask.progress))
                        break
                    }
                    
                    continuation.yield(.init(stage: .downloading, progress: downloadTask.progress))
                    log.debug("[Engine — Download] \(downloadTask.progress.fractionCompleted * 100)% complete")
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }

            // If the consumer drops the stream, stop the download
            continuation.onTermination = { @Sendable _ in
                if downloadTask.state == .running {
                    downloadTask.cancel()
                }
            }

            downloadTask.resume()
        }
    }

    static func fetchLatestUpdateVersion(stream: Stream = .init(rawValue: currentStream) ?? .stable) async throws -> SemanticVersion? {
        let sourceURL: URL = .init(string: "https://raw.githubusercontent.com/MythicApp/Engine/\(stream.rawValue)/properties.plist")!
        let (data, response) = try await URLSession.shared.data(from: sourceURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            return nil
        }

        let decoder = PropertyListDecoder()
        let versionData = try decoder.decode([String: SemanticVersion].self, from: data)

        return versionData["version"]
    }

    static var isUpdateAvailable: Bool? {
        get async {
            guard let latestVersion = try? await fetchLatestUpdateVersion(),
                  let currentVersion = version
            else { return nil }
            return latestVersion > currentVersion
        }
    }

    static func checkIfLatestVersionDownloadable(stream: Stream = .init(rawValue: currentStream) ?? .stable) async throws -> Bool? {
        let sourceURL: URL = .init(string: "https://api.github.com/repos/MythicApp/Engine/actions/runs")!
        let (data, response) = try await URLSession.shared.data(from: sourceURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            return nil
        }

        let json = try JSON(data: data)
        let runs = json["workflow_runs"]

        func isRunSuccessful(_ run: (key: String, value: JSON)) -> Bool {
            guard let status = run.1["status"].string,
                  let conclusion = run.1["conclusion"].string else {
                return false
            }

            return status == "completed" && conclusion == "success"
        }

        // get the most recent run and check for its success
        if let firstRun = runs.first(where: { $0.1["head_branch"].string == stream.rawValue }),
           isRunSuccessful(firstRun) {
            return true
        }

        return false
    }

    /// Removes Mythic Engine.
    static func remove() throws {
        guard exists else { throw NotInstalledError() }
        try files.removeItem(at: directory)
    }
}

extension Engine {
    struct NotInstalledView: View {
        @State private var isInstallationViewPresented: Bool = false

        @State private var installationError: Error?
        @State private var installationComplete: Bool = false

        var body: some View {
            VStack {
                if !Engine.exists {
                    ContentUnavailableView(
                        "Mythic Engine is not installed.",
                        systemImage: "arrow.down.circle.badge.xmark.fill",
                        description: .init("""
                    To access containers, Mythic Engine must be installed.
                    """)
                    )
                    Button("Install Mythic Engine", systemImage: "arrow.down.circle.fill") {
                        isInstallationViewPresented = true
                    }
                }
            }
            .sheet(isPresented: $isInstallationViewPresented) {
                EngineInstallationView(
                    isPresented: $isInstallationViewPresented,
                    installationError: $installationError,
                    installationComplete: $installationComplete
                )
                .padding()
            }
        }
    }
}
