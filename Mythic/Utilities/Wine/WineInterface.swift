//
//  WineInterface.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 30/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import Foundation
import OSLog

final class Wine { // TODO: https://forum.winehq.org/viewtopic.php?t=15416
    // MARK: - Variables

    /// Logger instance for swift parsing of wine.
    internal static let log = Logger(subsystem: Logger.subsystem, category: "wineInterface")

    /// The directory where all wine prefixes/containers related to Mythic are stored.
    static var containersDirectory: URL? {
        let directory = Bundle.appContainer!.appending(path: "Containers")
        if files.fileExists(atPath: directory.path) {
            return directory
        } else {
            do {
                Logger.file.info("Creating containers directory")
                try files.createDirectory(at: directory, withIntermediateDirectories: false)
                return directory
            } catch {
                Logger.app.error("Error creating Containers directory: \(error.localizedDescription)")
                return nil
            }
        }
    }

    static var containerURLs: Set<URL> {
        get {
            return .init((try? defaults.decodeAndGet([URL].self, forKey: "containerURLs")) ?? [])
        }
        set {
            do {
                try defaults.encodeAndSet(Array(newValue), forKey: "containerURLs")
            } catch {
                log.error("Unable to encode and/or set/update containerURLs array to UserDefaults: \(error.localizedDescription)")
            }
        }
    }

    static func getContainerObject(url: URL) throws -> Container {
        let decoder = PropertyListDecoder()
        return try decoder.decode(Container.self, from: .init(contentsOf: url.appending(path: "properties.plist")))
    }

    static var containerObjects: [Container] {
        return containerURLs.compactMap { try? getContainerObject(url: $0) }
    }

    private static func constructEnvironment(containerURL: URL?, withAdditionalFlags environment: [String: String]?) -> [String: String] {
        var constructedEnvironment: [String: String] = .init()
        if let containerURL = containerURL {
            constructedEnvironment["WINEPREFIX"] = containerURL.path
        }
        constructedEnvironment.merge(environment ?? .init(), uniquingKeysWith: { $1 })
        return constructedEnvironment
    }

    /// Run a wine command and collect stdout/stderr, returning the result.
    /// Prefer this for most operations that don't require interactive streaming.
    @discardableResult
    static func execute(
        arguments: [String],
        containerURL: URL?,
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        logCategory: String? = nil
    ) async throws -> Process.CommandResult {
        guard Engine.exists else {
            log.error("Mythic Engine is not installed.")
            throw Engine.NotInstalledError()
        }

        return try await Process.executeAsync(
            executableURL: Engine.directory.appending(path: "wine/bin/wine64"),
            arguments: arguments,
            environment: constructEnvironment(
                containerURL: containerURL,
                withAdditionalFlags: environment
            ),
            currentDirectoryURL: currentDirectoryURL
        )
    }

    // MARK: - API Methods (refactored to use run/execute)
    static func tasklist(containerURL url: URL) async throws -> [Container.Process] {
        var list: [Container.Process] = .init()

        // Collect output and parse after the process exits
        let result = try await execute(arguments: ["tasklist"], containerURL: url)
        result.standardOutput.enumerateLines { line, _ in
            if let match = try? Regex(#"(?P<name>[^,]+?),(?P<pid>\d+)"#).firstMatch(in: line) {
                var process: Container.Process = .init()
                process.name = String(match["name"]?.substring ?? "Unknown")
                process.pid = Int(match["pid"]?.substring ?? "0") ?? 0
                list.append(process)
            }
        }

        return list
    }

    // MARK: - Boot Method
    /**
     Boot a wine prefix/container.

     - Parameters:
     - baseURL: The URL where the container should be booted from.
     - name: The name that should be given to the container.
     - settings: Default settings the container should be booted with, if none already exist.
     - completion: A closure to call with the result (Container or Error).
     */
    @discardableResult
    static func boot(
        baseURL: URL? = containersDirectory,
        name: String,
        settings: ContainerSettings = .init()
    ) async throws -> Container {
        guard let baseURL = baseURL else {
            throw FileLocations.FileDoesNotExistError(URL(fileURLWithPath: "nil baseURL"))
        }
        guard files.fileExists(atPath: baseURL.path) else {
            throw FileLocations.FileDoesNotExistError(baseURL)
        }

        let url = baseURL.appending(path: name)

        guard Engine.exists else {
            throw Engine.NotInstalledError()
        }
        guard FileLocations.isWritableFolder(url: baseURL) else {
            throw FileLocations.FileNotModifiableError(url)
        }

        let hasExisted = containerExists(at: url)

        if !files.fileExists(atPath: url.path) {
            do {
                try files.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                log.error("Unable to create container directory: \(error.localizedDescription)")
                throw error
            }
        }

        defer {
            Task { @MainActor in
                VariableManager.shared.setVariable("booting", value: false)
            }
        }
        Task { @MainActor in
            VariableManager.shared.setVariable("booting", value: true)
        }

        do {
            let newContainer = Container(name: name, url: url, settings: settings)

            // Run wineboot and inspect stderr/stdout for the "updated" message.
            let result = try await execute(arguments: ["wineboot"], containerURL: url)

            // swiftlint:disable:next force_try
            if result.standardError.contains(try! Regex(#"wine: configuration in (.*?) has been updated\."#)) {
                containerURLs.insert(url)
                return newContainer
            }

            if hasExisted {
                log.notice("Container already exists at \(url.prettyPath())")
                if let container = Container(knownURL: url) {
                    return container
                } else {
                    throw ContainerAlreadyExistsError()
                }
            } else {
                await toggleRetinaMode(containerURL: url, toggle: settings.retinaMode)
                await setWindowsVersion(containerURL: url, version: settings.windowsVersion)
                await setDisplayScaling(containerURL: url, dpi: settings.scaling)
            }

            log.notice("Successfully booted container \"\(name)\"")
            return newContainer
        } catch {
            log.error("Boot failed for \(name): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete Container Method
    @discardableResult
    static func deleteContainer(containerURL: URL) throws -> Bool {
        Logger.file.notice("Deleting container \(containerURL.lastPathComponent) (\(containerURL))")
        guard containerExists(at: containerURL) else { throw ContainerDoesNotExistError() }
        try files.removeItem(at: containerURL)
        containerURLs.remove(containerURL)

        return true
    }

    // MARK: - Kill All Method
    static func killAll(containerURLs urls: [URL] = .init()) throws {
        let task = Process()
        task.executableURL = Engine.directory.appending(path: "wine/bin/wineserver")
        task.arguments = ["-k"]

        let urls: [URL] = urls.isEmpty ? .init(containerURLs) : urls

        for url in urls {
            task.environment = ["WINEPREFIX": url.path(percentEncoded: false)]
            task.qualityOfService = .utility
            try task.run()
        }
    }

    // MARK: - Clear Shader Cache Method
    static func purgeShaderCache(game: Game? = nil) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/getconf"
        task.arguments = ["DARWIN_USER_CACHE_DIR"]

        let pipe = Pipe()
        task.standardOutput = pipe
        do { try task.run() } catch { return false }

        let userCachePath = String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let d3dmcache = "\(userCachePath)/d3dm"

        task.waitUntilExit()

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: "do shell script \"sudo rm -rf \(d3dmcache)\" with administrator privileges") {
            let output = scriptObject.executeAndReturnError(&error)
            Logger.app.debug("output from shader cache purge: \(output.stringValue ?? "none")")

            if error != nil {
                return false
            }
        }

        return true
    }

    // MARK: - Add Registry Key Method
    private static func addRegistryKey(containerURL: URL, key: String, name: String, data: String, type: RegistryType) async throws {
        guard containerExists(at: containerURL) else { throw ContainerDoesNotExistError() }

        let result = try await execute(
            arguments: ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"],
            containerURL: containerURL
        )

        // Non-zero exit likely indicates failure to add key
        guard result.exitCode == 0 else {
            throw UnableToQueryRegistryError()
        }
    }

    // MARK: - Query Registry Key Method
    static func queryRegistryKey(containerURL: URL, key: String, name: String, type: RegistryType, completion: @escaping (Result<String, Error>) -> Void) async {
        do {
            let result = try await execute(
                arguments: ["reg", "query", key, "-v", name],
                containerURL: containerURL
            )

            // Gather non-empty, trimmed lines; return the last occurrence
            let lines = result.standardOutput
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if let last = lines.last {
                completion(.success(last))
            } else {
                completion(.failure(UnableToQueryRegistryError()))
            }
        } catch {
            log.error("\("Failed to query regkey \(type) \(name) \(key) in container at \(containerURL)")")
            completion(.failure(error))
        }
    }

    // MARK: - Toggle Retina Mode Method
    static func toggleRetinaMode(containerURL: URL, toggle: Bool) async {
        do {
            try await addRegistryKey(containerURL: containerURL, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", data: toggle ? "y" : "n", type: .string)
        } catch {
            log.error("Unable to toggle retina mode to \(toggle) in container at \(containerURL): \(error)")
        }
    }

    static func getRetinaMode(containerURL: URL) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await queryRegistryKey(
                    containerURL: containerURL,
                    key: RegistryKey.macDriver.rawValue,
                    name: "RetinaMode",
                    type: .string
                ) { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value == "y")
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    static func getWindowsVersion(containerURL: URL) async throws -> WindowsVersion? {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try await execute(
                        arguments: ["winecfg", "-v"],
                        containerURL: containerURL
                    )

                    if let version = WindowsVersion.allCases.first(where: { String(describing: $0) == result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                        continuation.resume(returning: version)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func setWindowsVersion(containerURL: URL, version: WindowsVersion) async {
        do {
            let result = try await execute(
                arguments: ["winecfg", "-v", String(describing: version)],
                containerURL: containerURL
            )
            if result.exitCode != 0 {
                log.error("winecfg -v \(version.rawValue) non-zero exit: \(result.exitCode)")
            }
        } catch {
            log.error("Unable to set windows version in \(containerURL.prettyPath()) to \(version.rawValue): \(error.localizedDescription)")
        }
    }

    static func getDisplayScaling(containerURL: URL) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await queryRegistryKey(
                    containerURL: containerURL,
                    key: RegistryKey.desktop.rawValue,
                    name: "LogPixels",
                    type: .dword
                ) { result in
                    switch result {
                    case .success(let value):
                        guard let scale = Int(value.trimmingPrefix("0x"), radix: 16) else {
                            continuation.resume(returning: -1)
                            return
                        }
                        continuation.resume(returning: scale)
                    case .failure(let error):
                        log.error("Unable to fetch display scaling value in container at \(containerURL): \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    static func setDisplayScaling(containerURL: URL, dpi: Int) async {
        guard (96...480).contains(dpi) else { return }
        do {
            try await addRegistryKey(
                containerURL: containerURL,
                key: RegistryKey.desktop.rawValue,
                name: "LogPixels",
                data: String(dpi),
                type: .dword
            )
        } catch {
            log.error("Unable to set display scaling value to \(dpi) DPI in container at \(containerURL): \(error)")
        }
    }

    // MARK: - Container Exists Method
    /**
     Check for a wine prefix/container's existence at a URL.

     - Parameter at: The `URL` of the container that needs to be checked.
     - Returns: Boolean value denoting the container's existence.
     */
    static func containerExists(at url: URL) -> Bool {
        return (try? files.contentsOfDirectory(atPath: url.path).contains("drive_c")) ?? false
    }
}
