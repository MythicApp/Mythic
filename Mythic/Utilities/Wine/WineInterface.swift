//
//  WineInterface.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 30/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import OSLog

final class Wine { // TODO: https://forum.winehq.org/viewtopic.php?t=15416
    // FIXME: TODO: all funcs should take urls as params not bottles
    // MARK: - Variables
    
    /// Logger instance for swift parsing of wine.
    internal static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "wineInterface")
    
    private static var _runningCommands: [String: Process] = .init()
    private static let _runningCommandsQueue = DispatchQueue(label: "legendaryRunningCommands", attributes: .concurrent)
    
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
    
    /// The directory where all wine prefixes related to Mythic are stored.
    static let bottlesDirectory: URL? = {
        let directory = Bundle.appContainer!.appending(path: "Bottles")
        if files.fileExists(atPath: directory.path) {
            return directory
        } else {
            do {
                Logger.file.info("Creating bottles directory")
                try files.createDirectory(at: directory, withIntermediateDirectories: false)
                return directory
            } catch {
                Logger.app.error("Error creating Bottles directory: \(error.localizedDescription)")
                return nil
            }
        }
    }()
    
    static var bottleURLs: Set<URL> { // FIXME: migrate from allBottles using plist decoder
        get { return .init((try? defaults.decodeAndGet([URL].self, forKey: "bottleURLs")) ?? []) }
        set {
            do {
                try defaults.encodeAndSet(Array(newValue), forKey: "bottleURLs")
            } catch {
                log.error("Unable to encode and/or set/update bottleURLs array to UserDefaults: \(error.localizedDescription)")
            }
        }
    }
    
    static func getBottleObject(url: URL) throws -> Bottle {
        let decoder = PropertyListDecoder()
        return try decoder.decode(Bottle.self, from: .init(contentsOf: url.appending(path: "properties.plist")))
    }
    
    static var bottleObjects: [Bottle] {
        return bottleURLs.compactMap { try? getBottleObject(url: $0) }
    }
    
    /*
    // MARK: - All Bottles Variable
    static var allBottles: [String: Bottle]? {
        get {
            if let object = try? defaults.decodeAndGet([String: Bottle].self, forKey: "allBottles") {
                return object
            } else {
                Logger.app.warning("No bottles exist, returning default")
                Task(priority: .high) { await Wine.boot(name: "Default") { _ in } }
                return .init() // FIXME: if already exists, might not get appended in time
            }
        }
        set { try? defaults.encodeAndSet(newValue, forKey: "allBottles") }
    }
     */
    
    static var defaultBottleSettings: BottleSettings { // Registered by AppDelegate
        get {
            let defaultValues: BottleSettings = .init(metalHUD: false, msync: true, retinaMode: true, DXVK: false, DXVKAsync: false, windowsVersion: .win11, scaling: 0.0)
            do {
                try defaults.encodeAndRegister(defaults: ["defaultBottleSettings": defaultValues])
            } catch {
                log.error("Unable to decode and/or get default bottle settings to UserDefaults: \(error.localizedDescription)")
            }
            return (try? defaults.decodeAndGet(BottleSettings.self, forKey: "defaultBottleSettings")) ?? defaultValues
        }
        set {
            do {
                try defaults.encodeAndSet(newValue, forKey: "defaultBottleSettings")
            } catch {
                log.error("Unable to encode and/or get default bottle settings to UserDefaults: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Command Method
    /**
     Run a wine command, using Mythic Engine's integrated wine.
     
     - Parameters:
     - args: The command arguments.
     - identifier: String to keep track of individual command functions. (originally UUID-based)
     - prefix: File URL to prefix wine should use to execute command.
     - input: Optional input string for the command.
     - inputIf: Optional condition to be checked for in the output streams before input is appended.
     - asyncOutput: Optional closure that gets output appended to it immediately.
     - additionalEnvironmentVariables: Optional dictionary that may contain other environment variables you wish to run with a command.
     
     - Returns: A tuple containing stdout and stderr data.
     */
    /**
     Executes Legendary's command-line process with the specified arguments and handles its output and input interactions.
     
     - Parameters:
      - args: The arguments to pass to the command-line process.
      - waits: Indicates whether the function should wait for the command-line process to complete before returning.
      - identifier: A unique identifier for the command-line process.
      - input: A closure that processes the output of the command-line process and provides input back to it.
      - environment: Additional environment variables to set for the command-line process.
      - completion: A closure to call with the output of the command-line process.
     
     - Throws: An error if the command-line process encounters an issue.
     
     This function executes a command-line process with the specified arguments and waits for it to complete if `waits` is `true`.
     It handles the process's standard input, standard output, and standard error, as well as any interactions based on the output provided by the `input` closure.
     */
    static func command(arguments args: [String], identifier: String, waits: Bool = true, bottleURL: URL?, input: ((String) -> String?)? = nil, environment: [String: String]? = nil, completion: @escaping (Legendary.CommandOutput) -> Void) async throws { // TODO: Combine Framework
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
        
        if let bottleURL = bottleURL {
            constructedEnvironment["WINEPREFIX"] = bottleURL.path
        }
        
        constructedEnvironment.merge(environment ?? .init(), uniquingKeysWith: { $1 })
                                     
        let terminalFormat = "\((constructedEnvironment.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
        task.environment = constructedEnvironment
        
        task.qualityOfService = .userInitiated
        
        let output: Legendary.CommandOutput = .init()
        
        stderr.fileHandleForReading.readabilityHandler = { [weak stdin, weak output] handle in
            let availableOutput = String(decoding: handle.availableData, as: UTF8.self)
            guard !availableOutput.isEmpty else { return }
            guard let stdin = stdin, let output = output else { return }
            if let trigger = input?(availableOutput), let data = trigger.data(using: .utf8) {
                log.debug("input detected, but current implementation is not tested.")
                stdin.fileHandleForWriting.write(data)
            }
            output.stderr = availableOutput
            completion(output)
        }
        
        stdout.fileHandleForReading.readabilityHandler = { [weak stdin, weak output] handle in
            let availableOutput = String(decoding: handle.availableData, as: UTF8.self)
            guard !availableOutput.isEmpty else { return }
            guard let stdin = stdin, let output = output else { return }
            if let trigger = input?(availableOutput), let data = trigger.data(using: .utf8) {
                log.debug("input detected, but current implementation is not tested.")
                stdin.fileHandleForWriting.write(data)
            }
            output.stdout = availableOutput
            completion(output)
        }
        
        task.terminationHandler = { _ in
            runningCommands.removeValue(forKey: identifier)
        }
        
        log.debug("[command] executing command [\(identifier)]: `\(terminalFormat)`")
        
        try task.run()
        
        runningCommands[identifier] = task // What if two commands with the same identifier execute close to each other?
        
        if waits { task.waitUntilExit() }
    }
    
    // TODO: implement
    /// ⚠︎ Incomplete implementation
    static func launchWinetricks(bottleURL: URL) throws {
        guard Engine.exists else {
            log.error("Unable to launch winetricks, Mythic Engine is not installed!")
            throw Engine.NotInstalledError()
        }
        
        let task = Process()
        task.executableURL = Engine.directory.appending(path: "winetricks")
        task.environment = ["WINEPREFIX": bottleURL.path(percentEncoded: false)]
        task.arguments = ["--gui"]
        
        try task.run()
    }
    
    // TODO: Implement tasklist
    /// Not implemented yet -- unnecessary at this time
    static func tasklist(bottleURL url: URL) throws -> [String: Int] {
        let list: [String: Int] = .init()
        Task {
            try await command(arguments: ["tasklist"], identifier: "tasklist", bottleURL: url) { output in
                
            }
        }
        return list
    }
    
    // MARK: - Boot Method
    /**
     Boot/Create a wine prefix. (This will create one if none exists in the URL provided in `prefix`)
     
     - Parameter prefix: The URL of the wine prefix to boot.
     */
    static func boot( // TODO: promises & combine framework
        baseURL: URL? = bottlesDirectory,
        name: String,
        settings: BottleSettings = defaultBottleSettings,
        completion: @escaping (Result<Bottle, Error>) -> Void
    ) async {
        guard let baseURL = baseURL else { return }
        guard files.fileExists(atPath: baseURL.path) else { completion(.failure(FileLocations.FileDoesNotExistError(baseURL))); return }
        let url = baseURL.appending(path: name)
        
        guard Engine.exists else { completion(.failure(Engine.NotInstalledError())); return }
        guard FileLocations.isWritableFolder(url: baseURL) else { completion(.failure(FileLocations.FileNotModifiableError(url))); return }
        let hasExisted = bottleExists(bottleURL: url)
        
        if !files.fileExists(atPath: url.path) {
            do {
                try files.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                completion(.failure(error))
                log.error("Unable to create bottle directory: \(error.localizedDescription)")
                return
            }
        }
        
        defer { VariableManager.shared.setVariable("booting", value: false) }
        VariableManager.shared.setVariable("booting", value: true)
        
        do {
            let newBottle: Bottle = .init(name: name, url: url, settings: settings)
            try await command(arguments: ["wineboot"], identifier: "wineboot", bottleURL: url) { output in
                // swiftlint:disable:next force_try
                if output.stderr.contains(try! Regex(#"wine: configuration in (.*?) has been updated\."#)) {
                    bottleURLs.insert(url)
                    completion(.success(newBottle))
                }
            }
            
            if !bottleURLs.contains(url) {
                completion(.failure(UnableToBootError()))
                return
            }
            
            if !hasExisted {
                await toggleRetinaMode(bottleURL: url, toggle: settings.retinaMode)
                await setWindowsVersion(settings.windowsVersion, bottleURL: url)
            }
            
            log.notice("Successfully booted prefix \"\(name)\"")
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Delete Bottle Method
    @discardableResult
    static func deleteBottle(bottleURL: URL) throws -> Bool {
        Logger.file.notice("Deleting \(bottleURL.lastPathComponent) (\(bottleURL))")
        guard bottleExists(bottleURL: bottleURL) else { throw BottleDoesNotExistError() }
        try files.removeItem(at: bottleURL)
        bottleURLs.remove(bottleURL)
        
        return true
    }
    
    // MARK: - Kill All Method
    static func killAll(bottleURL: URL? = nil) throws {
        let task = Process()
        task.executableURL = Engine.directory.appending(path: "wine/bin/wineserver")
        task.arguments = ["-k"]
        
        let urls = bottleURL.map { [$0] } ?? bottleURLs
        for url in urls {
            task.environment = ["WINEPREFIX": url.path(percentEncoded: false)]
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
    private static func addRegistryKey(bottleURL: URL, key: String, name: String, data: String, type: RegistryType) async throws {
        guard bottleExists(bottleURL: bottleURL) else { throw BottleDoesNotExistError() }
        
        try await command(arguments: ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"], identifier: "regadd", bottleURL: bottleURL) { _  in
            // FIXME: errors aren't handled
        }
    }
    
    // MARK: - Query Registry Key Method
    static func queryRegistryKey(bottleURL: URL, key: String, name: String, type: RegistryType, completion: @escaping (Result<String, Error>) -> Void) async {
        var outputs: [String] = .init()
        do {
            try await command(arguments: ["reg", "query", key, "-v", name], identifier: "regquery", bottleURL: bottleURL) { output in
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
            log.error("\("Failed to query regkey \(type) \(name) \(key) in bottle at \(bottleURL)")")
            completion(.failure(error))
        }
    }
    
    // MARK: - Toggle Retina Mode Method
    static func toggleRetinaMode(bottleURL: URL, toggle: Bool) async {
        do {
            try await addRegistryKey(bottleURL: bottleURL, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", data: toggle ? "y" : "n", type: .string)
        } catch {
            log.error("Unable to toggle retina mode to \(toggle) in bottle at \(bottleURL): \(error)")
        }
    }
    
    static func getRetinaMode(bottleURL: URL) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await queryRegistryKey(
                    bottleURL: bottleURL, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", type: .string
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
    
    static func getWindowsVersion(bottleURL: URL) async throws -> WindowsVersion? { // conv to combine
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try await command(arguments: ["winecfg", "-v"], identifier: "getWindowsVersion", bottleURL: bottleURL) { output in
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
    
    static func setWindowsVersion(_ version: WindowsVersion, bottleURL: URL) async {
        do {
            try await command(arguments: ["winecfg", "-v", String(describing: version)], identifier: "getWindowsVersion", bottleURL: bottleURL) { _ in }
        } catch {
            log.error("Unable to set windows version in \(bottleURL.prettyPath()) to \(version.rawValue): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Prefix Exists Method
    /**
     Check for a wine prefix's existence at a file URL.
     
     - Parameter at: The `URL` of the prefix that needs to be checked.
     - Returns: Boolean value denoting the prefix's existence.
     */
    static func bottleExists(bottleURL: URL) -> Bool {
        return (try? files.contentsOfDirectory(atPath: bottleURL.path).contains("drive_c")) ?? false
    }
}
