//
//  Libraries.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

import Foundation
import ZIPFoundation
import SemanticVersion
import CryptoKit
import OSLog

private let files = FileManager.default

class Libraries {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Libraries"
    )

    static let directory = Bundle.appHome!.appending(path: "Libraries")

    private static let dataLock = NSLock()

    /// Check the Libraries folder's checksum.
    static func checksum() -> String {
        var dataAggregate = Data()

        if let enumerator = FileManager.default.enumerator(atPath: directory.path) {
            for case let fileURL as URL in enumerator {
                do { try dataAggregate.append(Data(contentsOf: fileURL)) }
                catch { Logger.file.error("Error reading libraries and generating a checksum: \(error)") }
            }
        }

        let checksum = dataAggregate.hash.map { String(format: "%02hhx", $0) }.joined()

        return checksum
    }

    /// Install Libraries, as MythicGPTKBuilder artifacts
    static func install(
        downloadProgressHandler: @escaping (Double) -> Void,
        installProgressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) { // storage check later?
        guard !isInstalled() else { completion(.failure(AlreadyInstalledError())); return }

        let session = URLSession(configuration: .default)

        let installProgress = Progress(totalUnitCount: 100)

        let download = session.downloadTask(
            with: URL(string: "https://nightly.link/MythicApp/GPTKBuilder/workflows/build-gptk/main/Libraries.zip")!
        ) { (file, response, error) in
            guard error == nil else {
                Logger.network.error("Error with GPTK download: \(error)")
                completion(.failure(error!))
                return
            }

            dataLock.lock()
            defer { dataLock.unlock() }

            if let file = file {
                do {
                    Logger.file.notice("Installing libraries...")
                    try files.unzipItem(at: file, to: directory, progress: installProgress)
                    Logger.file.notice("Finished downloading and installing libraries.")

                    let checksum = checksum()
                    UserDefaults.standard.set(checksum, forKey: "LibrariesChecksum")
                    Logger.file.notice("Libraries checksum is: \(checksum)")

                    completion(.success(true))
                } catch {
                    Logger.file.error("Unable to install libraries to \(directory.relativePath): \(error)")
                    completion(.failure(error))
                }
            }
        }

        let queue = DispatchQueue(label: "InstallProgress")

        queue.async {
            while !download.progress.isFinished {
                downloadProgressHandler(((Double(download.countOfBytesReceived) / Double(600137702)))) // rough estimate as of 235579c
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        queue.async {
            while !installProgress.isFinished {
                installProgressHandler(installProgress.fractionCompleted)
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        download.resume()
    }

    static func isInstalled() -> Bool {
        return
            files.fileExists(atPath: directory.path) &&
            checksum() == UserDefaults.standard.string(forKey: "LibrariesChecksum")
        ? true : false
    }

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
        ) { (data, response, error) in
            defer { group.leave() }

            guard error == nil else {
                log.error("Unable to check for new GPTK version: \(error)")
                return
            }

            guard let data = data else {
                return
            }

            do { latestVersion = try PropertyListDecoder().decode([String: SemanticVersion].self, from: data)["version"] ?? latestVersion }
            catch { log.error("Unable to decode upstream GPTK version.") }
        }
        .resume()
        group.wait()

        return latestVersion
    }

    static func remove(completion: @escaping (Result<Bool, Error>) -> Void) {
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
            Logger.file.error("Unable to remove libraries: \(error)")
            completion(.failure(error))
        }
    }
}
