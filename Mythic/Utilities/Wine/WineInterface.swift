//
//  WineInterface.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 30/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

final class Wine { // TODO: https://forum.winehq.org/viewtopic.php?t=15416
    // FIXME: TODO: all funcs should take urls as params not containers
    // MARK: - Variables
    
    /// Logger instance for swift parsing of wine.
    internal static let log = Logger(subsystem: Logger.subsystem, category: "wineInterface")
    
    private static var _runningCommands: [String: Process] = .init()
    private static let _runningCommandsQueue = DispatchQueue(label: "wineRunningCommands", attributes: .concurrent)

    /// Dictionary to monitor running commands and their identifiers.
    static var runningCommands: [String: Process] {
        get {
            var result: [String: Process]?
            _runningCommandsQueue.sync {
                result = _runningCommands
            }
            return result ?? [:]
        }
        set(newValue) {
            _runningCommandsQueue.async(flags: .barrier) {
                _runningCommands = newValue
            }
        }
    }
    
    /// The directory where all wine prefixes/containers related to Mythic are stored.
    static let containersDirectory: URL? = {
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
    }()
    
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

    // MARK: - Command Method
    /**
     Executes a wine command using Mythic Engine's integrated wine with the specified arguments, handling input & output interactions.
     
     - Parameters:
      - arguments: The arguments to pass to the command-line process.
      - waits: Indicates whether the function should wait for the command-line process to complete before returning.
      - containerURL: The URL of the wine prefix to execute the command in.
      - input: A closure that processes the output of the command-line process and provides input back to it.
      - environment: Additional environment variables to set for the command-line process.
      - completion: A closure to call with the output of the command-line process.
     
     This function executes a command-line process with the specified arguments and waits for it to complete if `waits` is `true`.
     It handles the process's standard input, standard output, and standard error, as well as any interactions based on the output provided by the `input` closure.
     */
    static func command(arguments args: [String], identifier: String, waits: Bool = true, containerURL: URL?, input: ((Process.CommandOutput) -> String?)? = nil, environment: [String: String]? = nil, completion: @escaping (Process.CommandOutput) -> Void) async throws { // TODO: Combine Framework
        let task = Process()
        task.executableURL = Engine.directory.appending(path: "wine/bin/wine64")
        
        let stdin: Pipe = .init()
        let stderr: Pipe = .init()
        let stdout: Pipe = .init()
        
        task.standardInput = stdin
        task.standardError = stderr
        task.standardOutput = stdout
        
        task.arguments = args
        
        // Construct environment variables (I prefer it this way instead of all at once)
        var constructedEnvironment: [String: String] = .init()
        
        if let containerURL = containerURL {
            constructedEnvironment["WINEPREFIX"] = containerURL.path
        }
        
        constructedEnvironment.merge(environment ?? .init(), uniquingKeysWith: { $1 })
                                     
        let terminalFormat = "\((constructedEnvironment.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
        task.environment = constructedEnvironment
        
        task.qualityOfService = .userInitiated
        
        let output: Process.CommandOutput = .init() // FIXME: data race
        let outputQueue: DispatchQueue = .init(label: "wineOutputQueue")

        stderr.fileHandleForReading.readabilityHandler = { [stdin, weak output] handle in
            let availableOutput = String(decoding: handle.availableData, as: UTF8.self)
            guard !availableOutput.isEmpty, let output = output else { return }

            outputQueue.async {
                output.stderr = availableOutput

                if let trigger = input?(output), let data = trigger.data(using: .utf8) {
                    log.debug("[command] [output] [stderr] \"\(availableOutput)\" found, writing \"\(String(decoding: data, as: UTF8.self))\" to stdin.")
                    stdin.fileHandleForWriting.write(data)
                }

                completion(output)
                log.debug("[command] [stderr] \(availableOutput)")
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { [stdin, weak output] handle in
            let availableOutput = String(decoding: handle.availableData, as: UTF8.self)
            guard !availableOutput.isEmpty, let output = output else { return }

            outputQueue.async {
                output.stdout = availableOutput

                if let trigger = input?(output), let data = trigger.data(using: .utf8) {
                    log.debug("[command] [output] [stdout] \"\(availableOutput)\" found, writing \"\(String(decoding: data, as: UTF8.self))\" to stdin.")
                    stdin.fileHandleForWriting.write(data)
                }

                completion(output)
                log.debug("[command] [stdout] \(availableOutput)")
            }
        }

        task.terminationHandler = { _ in
            runningCommands.removeValue(forKey: identifier)
        }
        
        log.debug("[command] [exec] [id: \(identifier)]: `\(terminalFormat)`")

        try task.run()
        
        runningCommands[identifier] = task // What if two commands with the same identifier execute close to each other?
        
        if waits { task.waitUntilExit() }
    }
    
    // TODO: implement
    /// ⚠︎ Incomplete implementation
    static func launchWinetricks(containerURL: URL) throws {
        guard Engine.exists else {
            log.error("Unable to launch winetricks, Mythic Engine is not installed.")
            throw Engine.NotInstalledError()
        }
        
        let task = Process()
        task.executableURL = Engine.directory.appending(path: "winetricks")
        task.environment = ["WINEPREFIX": containerURL.path(percentEncoded: false)]
        task.arguments = ["--gui"]
        
        try task.run()
    }
    
    // FIXME: tasklist impossible with current command() implementation, TODO: large refactor
    static func tasklist(containerURL url: URL) throws -> [String: Int] {
        let list: [String: Int] = .init()
        Task {
            try await command(arguments: ["tasklist"], identifier: "tasklist", containerURL: url) { output in
                
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
        - completion: A closure to call with the output of the command-line process.
     */
    static func boot( // TODO: promises & combine framework
        baseURL: URL? = containersDirectory,
        name: String,
        settings: ContainerSettings = .init(),
        completion: @escaping (Result<Container, Error>) -> Void
    ) async {
        guard let baseURL = baseURL else { return }
        guard files.fileExists(atPath: baseURL.path) else { completion(.failure(FileLocations.FileDoesNotExistError(baseURL))); return }
        let url = baseURL.appending(path: name)
        
        guard Engine.exists else { completion(.failure(Engine.NotInstalledError())); return }
        guard FileLocations.isWritableFolder(url: baseURL) else { completion(.failure(FileLocations.FileNotModifiableError(url))); return }
        let hasExisted = containerExists(at: url)
        
        if !files.fileExists(atPath: url.path) {
            do {
                try files.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                completion(.failure(error))
                log.error("Unable to create container directory: \(error.localizedDescription)")
                return
            }
        }
        
        defer { VariableManager.shared.setVariable("booting", value: false) }
        VariableManager.shared.setVariable("booting", value: true)
        
        do {
            let newContainer: Container = .init(name: name, url: url, settings: settings)
            try await command(arguments: ["wineboot"], identifier: "wineboot", containerURL: url) { output in
                // swiftlint:disable:next force_try
                if output.stderr.contains(try! Regex(#"wine: configuration in (.*?) has been updated\."#)) {
                    containerURLs.insert(url)
                    completion(.success(newContainer))
                }
            }
            
            if hasExisted {
                log.notice("Container already exists at \(url.prettyPath())")
                if let container: Container = .init(knownURL: url) {
                    completion(.success(container))
                } else {
                    completion(.failure(ContainerAlreadyExistsError()))
                }
            } else {
                await toggleRetinaMode(containerURL: url, toggle: settings.retinaMode)
                await setWindowsVersion(containerURL: url, version: settings.windowsVersion)
                await setDisplayScaling(containerURL: url, dpi: settings.scaling)
            }
            
            log.notice("Successfully booted container \"\(name)\"")
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Delete Container Method
    @discardableResult
    static func deleteContainer(containerURL: URL) throws -> Bool {
        Logger.file.notice("Deleting \(containerURL.lastPathComponent) (\(containerURL))")
        guard containerExists(at: containerURL) else { throw ContainerDoesNotExistError() }
        try files.removeItem(at: containerURL)
        containerURLs.remove(containerURL)
        
        return true
    }
    
    // MARK: - Kill All Method
    static func killAll(containerURL: URL? = nil) throws {
        let task = Process()
        task.executableURL = Engine.directory.appending(path: "wine/bin/wineserver")
        task.arguments = ["-k"]
        
        let urls: [URL] = containerURL.map { [$0] } ?? .init(containerURLs)
        
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
        
        try await command(arguments: ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"], identifier: "regadd", containerURL: containerURL) { _  in
            // FIXME: errors aren't handled
        }
    }
    
    // MARK: - Query Registry Key Method
    static func queryRegistryKey(containerURL: URL, key: String, name: String, type: RegistryType, completion: @escaping (Result<String, Error>) -> Void) async {
        var outputs: [String] = .init()
        do {
            try await command(arguments: ["reg", "query", key, "-v", name], identifier: "regquery", containerURL: containerURL) { output in
                let trimmedLine = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedLine.isEmpty {
                    outputs.append(trimmedLine)
                }
            }
            
            if !outputs.isEmpty {
                completion(.success(String(outputs.last!)))
            } else {
                completion(.failure(UnableToQueryRegistryError()))
                runningCommands["regquery"]?.terminate(); return
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
                    try await command(
                        arguments: ["winecfg", "-v"],
                        identifier: "getWindowsVersion",
                        containerURL: containerURL
                    ) { output in
                        if let version: WindowsVersion = .allCases.first(where: { String(describing: $0) == output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                            continuation.resume(returning: version)
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func setWindowsVersion(containerURL: URL, version: WindowsVersion) async {
        do {
            try await command(
                arguments: [
                    "winecfg", "-v",
                    String(describing: version)
                ],
                identifier: "setWindowsVersion",
                containerURL: containerURL
            ) { _ in }
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
