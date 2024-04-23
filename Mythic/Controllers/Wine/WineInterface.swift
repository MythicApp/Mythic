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

class Wine { // TODO: https://forum.winehq.org/viewtopic.php?t=15416
    // FIXME: TODO: all funcs should take urls as params not bottles
    // MARK: - Variables
    
    /// Logger instance for swift parsing of wine.
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "wineInterface")
    
    private static var _runningCommands: [String: Process] = .init()
    private static let _runningCommandsQueue = DispatchQueue(label: "legendaryRunningCommands", attributes: .concurrent)
    
    /// Dictionary to monitor running commands and their identifiers.
    private static var runningCommands: [String: Process] {
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
    
    // MARK: - All Bottles Variable
    static var allBottles: [String: Bottle]? {
        get {
            if let object = defaults.object(forKey: "allBottles") as? Data {
                do {
                    return try PropertyListDecoder().decode(Dictionary.self, from: object)
                } catch {
                    Logger.app.error("Unable to retrieve bottles: \(error.localizedDescription)")
                    return nil
                }
            } else {
                Logger.app.warning("No bottles exist, returning default")
                Task(priority: .high) { await Wine.boot(name: "Default") { _ in } }
                return .init() // FIXME: if already exists, might not get appended in time
            }
        }
        set {
            do {
                defaults.set(
                    try PropertyListEncoder().encode(newValue),
                    forKey: "allBottles"
                )
            } catch {
                Logger.app.error("Unable to set to bottles: \(error.localizedDescription)")
            }
        }
    }
    
    static var defaultBottleSettings: BottleSettings {
        get { return defaults.object(forKey: "defaultBottleSettings") as? BottleSettings ?? .init(metalHUD: false, msync: true, retinaMode: true) }
        set { defaults.set(newValue, forKey: "defaultBottleSettings") }
    }
    
    @available(*, message: "keys MUST BE game.id + variable currently unused")
    static var individualBottleSettings: [String: BottleSettings]? {
        get {
            if let object = defaults.object(forKey: "individualBottleSettings") as? Data {
                do {
                    return try PropertyListDecoder().decode(Dictionary.self, from: object)
                } catch {
                    Logger.app.error("Unable to retrieve individual bottle settings: \(error.localizedDescription)")
                    return nil
                }
            } else {
                Logger.app.warning("No games use individual bottle settings, returning default")
                return .init()
            }
        }
        set {
            do {
                defaults.set(
                    try PropertyListEncoder().encode(newValue),
                    forKey: "individualBottleSettings"
                )
            } catch {
                Logger.app.error("Unable to set to individual bottle settings: \(error.localizedDescription)")
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
    @available(*, message: "Revamped recently")
    static func command(arguments args: [String], identifier: String, waits: Bool = true, bottleURL: URL, input: ((String) -> String?)? = nil, environment: [String: String]? = nil, completion: @escaping (Legendary.CommandOutput, Process) -> Void) async throws {
        let task = Process()
        task.executableURL = Libraries.directory.appending(path: "Wine/bin/wine64")
        
        let stdin: Pipe = .init()
        let stderr: Pipe = .init()
        let stdout: Pipe = .init()
        
        task.standardInput = stdin
        task.standardError = stderr
        task.standardOutput = stdout
        
        task.arguments = args
        
        let constructedEnvironment = ["WINEPREFIX": bottleURL.path].merging(environment ?? .init(), uniquingKeysWith: { $1 })
        let terminalFormat = "\((constructedEnvironment.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
        task.environment = constructedEnvironment
        
        task.qualityOfService = .userInitiated
        
        let output: Legendary.CommandOutput = .init()
        
        stderr.fileHandleForReading.readabilityHandler = { [stdin, output] handle in
            guard let availableOutput = String(data: handle.availableData, encoding: .utf8), !availableOutput.isEmpty else { return }
            if let trigger = input?(availableOutput), let data = trigger.data(using: .utf8) {
                print("wanting to go!!!")
                stdin.fileHandleForWriting.write(data)
            }
            output.stderr = availableOutput
            completion(output, task) // ⚠️ FIXME: critical performance issues
        }
        
        stdout.fileHandleForReading.readabilityHandler = { [stdin, output] handle in
            guard let availableOutput = String(data: handle.availableData, encoding: .utf8), !availableOutput.isEmpty else { return }
            if let trigger = input?(availableOutput), let data = trigger.data(using: .utf8) {
                print("wanting to go!!!")
                stdin.fileHandleForWriting.write(data)
            }
            output.stdout = availableOutput
            completion(output, task) // ⚠️ FIXME: critical performance issues
        }
        
        task.terminationHandler = { [stdin] _ in
            runningCommands.removeValue(forKey: identifier)
            try? stdin.fileHandleForWriting.close()
        }
        
        log.debug("[command] executing command [\(identifier)]: `\(terminalFormat)`")
        
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    try task.run()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        runningCommands[identifier] = task
        
        if waits { task.waitUntilExit() }
    }
    
    // TODO: implement
    @available(*, message: "Not implemented completely.")
    static func launchWinetricks(prefix: URL) throws {
        guard Libraries.isInstalled() else {
            log.error("Unable to launch winetricks, Mythic Engine is not installed!")
            throw Libraries.NotInstalledError()
        }
        
        let task = Process()
        task.executableURL = Libraries.directory.appending(path: "winetricks")
        task.environment = ["WINEPREFIX": prefix.path(percentEncoded: false)]
        do {
            try task.run()
        } catch {
            // TODO: implement
            // doesn't work if zenity isn't installed
        }
    }
    
    // MARK: - Boot Method
    /**
     Boot/Create a wine prefix. (This will create one if none exists in the URL provided in `prefix`)
     
     - Parameter prefix: The URL of the wine prefix to boot.
     */
    static func boot(
        baseURL: URL? = bottlesDirectory,
        name: String,
        settings: BottleSettings = defaultBottleSettings,
        completion: @escaping (Result<Bottle, Error>) -> Void
    ) async {
        guard let baseURL = baseURL else { return }
        guard files.fileExists(atPath: baseURL.path) else { completion(.failure(FileLocations.FileDoesNotExistError(baseURL))); return }
        let bottleURL = baseURL.appending(path: name)
        
        guard Libraries.isInstalled() else { completion(.failure(Libraries.NotInstalledError())); return }
        guard FileLocations.isWritableFolder(url: baseURL) else { completion(.failure(FileLocations.FileNotModifiableError(bottleURL))); return }
        
        if !files.fileExists(atPath: bottleURL.path) {
            do {
                try files.createDirectory(at: bottleURL, withIntermediateDirectories: true)
            } catch {
                completion(.failure(error))
                log.error("Unable to create prefix directory: \(error.localizedDescription)")
            }
        }
        
        defer { VariableManager.shared.setVariable("booting", value: false) }
        VariableManager.shared.setVariable("booting", value: true)
        
        if allBottles?[name] == nil { // FIXME: may be unsafe
            allBottles?[name] = .init(url: bottleURL, settings: settings, busy: true)
        } else {
            completion(.failure(BottleAlreadyExistsError()))
            return
        }
        
        do {
            let newBottle: Bottle = .init(url: bottleURL, settings: settings, busy: false)
            try await command(arguments: ["wineboot"], identifier: "wineboot", bottleURL: bottleURL) { output, _ in
                // swiftlint:disable:next force_try
                if output.stderr.contains(try! Regex(#"wine: configuration in (.*?) has been updated\."#)) {
                    allBottles?[name] = newBottle
                    completion(.success(newBottle))
                }
            }
            
            // how to throw bottle error now??
            
            log.notice("Successfully booted prefix \"\(name)\"")
            
            try await toggleRetinaMode(bottleURL: bottleURL, toggle: settings.retinaMode)
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Delete Bottle Method
    @discardableResult
    static func deleteBottle(bottleURL: URL) throws -> Bool {
        Logger.file.notice("Deleting \(bottleURL.lastPathComponent) (\(bottleURL))")
        guard bottleExists(bottleURL: bottleURL) else { throw BottleDoesNotExistError() }
        
        if files.fileExists(atPath: bottleURL.path(percentEncoded: false)) { try files.removeItem(at: bottleURL) }
        if let bottles = allBottles { allBottles = bottles.filter { $0.value.url != bottleURL } }
        
        return true
    }
    
    // MARK: - Kill All Method
    @discardableResult
    static func killAll(bottleURL: URL? = nil) -> Bool {
        let task = Process()
        task.executableURL = Libraries.directory.appending(path: "Wine/bin/wineserver")
        task.arguments = ["-k"]
        
        if let bottleURL = bottleURL {
            task.environment = ["WINEPREFIX": bottleURL.path(percentEncoded: false)]
            do { try task.run() } catch { return false }
        } else {
            if let bottles = Wine.allBottles {
                for bottle in bottles.values {
                    task.environment = ["WINEPREFIX": bottle.url.path(percentEncoded: false)]
                    do { try task.run() } catch { return false }
                }
            }
        }
        
        return true
    }
    // MARK: - Clear Shader Cache Method
    static func purgeShaderCache(game: Game? = nil) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/getconf"
        task.arguments = ["DARWIN_USER_CACHE_DIR"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        do { try task.run() } catch { return false }
        
        guard let userCachePath = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return false }
        
        let d3dmcache = "\(userCachePath)/d3dm"
        
        task.waitUntilExit()
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(
            source: """
            do shell script \"sudo rm -rf \(d3dmcache)\" with administrator privileges
            """) {
            
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
        
        try await command(arguments: ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"], identifier: "regadd", bottleURL: bottleURL) { _, _  in
            // FIXME: errors aren't handled
        }
    }
    
    // MARK: - Query Registry Key Method
    private static func queryRegistryKey(bottleURL: URL, key: String, name: String, type: RegistryType, completion: @escaping (Result<String, Error>) -> Void) async {
        do {
            
            try await command(arguments: ["reg", "query", key, "-v", name], identifier: "regquery", bottleURL: bottleURL) { output, task  in
                if output.stdout.contains(type.rawValue) {
                    let array = output.stdout.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
                    if !array.isEmpty {
                        completion(.success(String(array.last!)))
                    } else {
                        completion(.failure(UnableToQueryRegistyError()))
                        task.suspend(); return
                    }
                }
                // FIXME: outside errors aren't handled
            }
        } catch {
            log.error("\("Failed to query regkey \(type) \(name) \(key) in bottle at \(bottleURL)")")
            completion(.failure(error))
        }
    }
    
    // MARK: - Toggle Retina Mode Method
    static func toggleRetinaMode(bottleURL: URL, toggle: Bool) async throws {
        do {
            try await addRegistryKey(bottleURL: bottleURL, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", data: toggle ? "y" : "n", type: .string)
        } catch {
            log.error("Unable to toggle retina mode to \(toggle ? "on" : "off") in bottle at \(bottleURL)")
        }
    }
    
    static func getRetinaMode(bottleURL: URL, completion: @escaping (Result<Bool, Error>) -> Void) async {
        await Wine.queryRegistryKey(
            bottleURL: bottleURL, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", type: .string
        ) { result in
            switch result {
            case .success(let value):
                completion(.success(value == "y"))
            case .failure(let error):
                completion(.failure(error))
            }
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
