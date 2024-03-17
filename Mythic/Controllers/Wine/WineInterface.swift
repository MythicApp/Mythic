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
    static let bottlesDirectory: URL? = { // FIXME: allow force-unwrapping of bottles directory, directory creation error will be rare
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
    @discardableResult
    static func command(
        args: [String],
        identifier: String,
        bottleURL: URL,
        input: String? = nil,
        inputIf: InputIfCondition? = nil,
        asyncOutput: OutputHandler? = nil,
        additionalEnvironmentVariables: [String: String]? = nil
    ) async throws -> (stdout: Data, stderr: Data) {
        
        guard Libraries.isInstalled() else {
            log.error(
                """
                Unable to execute wine command, Mythic Engine is not installed!
                If you see this error, it needs to be handled by the script that invokes it.
                Contact blackxfiied on Discord or open an issue on GitHub.
                """
            )
            throw Libraries.NotInstalledError()
        }
        
        guard files.fileExists(atPath: bottleURL.path) else {
            log.error("Unable to execute wine command, prefix does not exist.")
            throw FileLocations.FileDoesNotExistError(bottleURL)
        }
        
        guard files.isWritableFile(atPath: bottleURL.path) else {
            log.error("Unable to execute wine command, prefix directory is not writable.")
            throw FileLocations.FileNotModifiableError(bottleURL)
        }
        
        let queue: DispatchQueue = DispatchQueue(label: "wineCommand", attributes: .concurrent)
        
        let commandKey = String(describing: args)
        
        let task = Process()
        task.executableURL = Libraries.directory.appending(path: "Wine/bin/wine64")
        
        struct PipeContainer {
            let stdout = Pipe()
            let stderr = Pipe()
            let stdin = Pipe()
        }
        
        actor DataContainer {
            private var _stdout = Data()
            private var _stderr = Data()
            
            func append(_ data: Data, to stream: Stream) {
                switch stream {
                case .stdout:
                    _stdout.append(data)
                case .stderr:
                    _stderr.append(data)
                }
            }
            
            var stdout: Data { return _stdout }
            var stderr: Data { return _stderr }
        }
        
        let pipe = PipeContainer()
        let data = DataContainer()
        
        task.standardError = pipe.stderr
        task.standardOutput = pipe.stdout
        task.standardInput = input != nil ? pipe.stdin : nil
        
        task.arguments = args
        
        var defaultEnvironmentVariables: [String: String] = bottleURL.path.isEmpty ? .init() : ["WINEPREFIX": bottleURL.path]
        if let additionalEnvironmentVariables = additionalEnvironmentVariables {
            defaultEnvironmentVariables.merge(additionalEnvironmentVariables) { (_, new) in new }
        }
        task.environment = defaultEnvironmentVariables
        
        let fullCommand = "\((defaultEnvironmentVariables.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
        task.qualityOfService = .userInitiated
        
        log.debug("executing \(fullCommand)")
        
        // MARK: Asynchronous stdout Appending
        queue.async(qos: .utility) {
            Task(priority: .high) { // already lowered by queue.async qos
                while true {
                    let availableData = pipe.stdout.fileHandleForReading.availableData
                    if availableData.isEmpty { break }
                    
                    await data.append(availableData, to: .stdout)
                    
                    if let inputIf = inputIf, inputIf.stream == .stdout {
                        if let availableData = String(data: availableData, encoding: .utf8), availableData.contains(inputIf.string) {
                            if let inputData = input?.data(using: .utf8) {
                                pipe.stdin.fileHandleForWriting.write(inputData)
                                pipe.stdin.fileHandleForWriting.closeFile()
                            }
                        }
                    }
                    
                    if let asyncOutput = asyncOutput, let outputString = String(data: availableData, encoding: .utf8) {
                        asyncOutput.stdout(outputString)
                    }
                }
            }
        }
        
        // MARK: Asynchronous stderr Appending
        queue.async(qos: .utility) {
            Task(priority: .high) { // already lowered by queue.async qos
                while true {
                    let availableData = pipe.stderr.fileHandleForReading.availableData
                    if availableData.isEmpty { break }
                    
                    await data.append(availableData, to: .stderr)
                    
                    if let inputIf = inputIf, inputIf.stream == .stderr {
                        if let availableData = String(data: availableData, encoding: .utf8) {
                            if availableData.contains(inputIf.string) {
                                if let inputData = input?.data(using: .utf8) {
                                    pipe.stdin.fileHandleForWriting.write(inputData)
                                    pipe.stdin.fileHandleForWriting.closeFile()
                                }
                            }
                        }
                    }
                    
                    if let asyncOutput = asyncOutput, let outputString = String(data: availableData, encoding: .utf8) {
                        asyncOutput.stderr(outputString)
                    }
                }
            }
        }
        
        if let input = input, !input.isEmpty && inputIf == nil {
            if let inputData = input.data(using: .utf8) {
                pipe.stdin.fileHandleForWriting.write(inputData)
                pipe.stdin.fileHandleForWriting.closeFile()
            }
        }
        
        // MARK: Run
        do {
            defer { runningCommands.removeValue(forKey: identifier) }
            runningCommands[identifier] = task // WHAT
            
            try task.run()
            
            task.waitUntilExit()
        } catch {
            log.fault("Legendary fault: \(error.localizedDescription)")
            return (Data(), Data())
        }
        
        // MARK: - Output (stderr/out) Handler
        let output: (stdout: Data, stderr: Data) = await (
            data.stdout, data.stderr
        )
        
        if let stderrString = String(data: output.stderr, encoding: .utf8), !stderrString.isEmpty {
            log.debug("\(stderrString)")
        } else {
            log.debug("stderr empty or nonexistent for command \(commandKey)")
        }
        
        if let stdoutString = String(data: output.stdout, encoding: .utf8) {
            if !stdoutString.isEmpty {
                log.debug("\(stdoutString)")
            }
        } else {
            log.debug("stdout empty or nonexistent for command \(commandKey)")
        }
        
        return output
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
        
        // TODO: FIXME: !!IMPORTANT!! replace throwing async functions with completion handlers - [completion: @escaping (Result<Void, Error>) -> Void]
        defer { VariableManager.shared.setVariable("booting", value: false) }
        VariableManager.shared.setVariable("booting", value: true) // TODO: rember
        
        if allBottles?[name] == nil { // FIXME: may be unsafe
            allBottles?[name] = .init(url: bottleURL, settings: settings, busy: true)
        } else {
            completion(.failure(BottleAlreadyExistsError()))
            return
        }
        
        do {
            let output = try await command(
                args: ["wineboot"],
                identifier: "wineboot",
                bottleURL: bottleURL
            )
            
            if let stderr = String(data: output.stderr, encoding: .utf8),
               !stderr.contains(try Regex(#"wine: configuration in (.*?) has been updated\."#)),
               !bottleExists(bottleURL: bottleURL) {
                log.error("Unable to boot prefix \"\(name)\"")
                completion(.failure(BootError()))
            }
            
            log.notice("Successfully booted prefix \"\(name)\"")
            let newBottle: Bottle = .init(url: bottleURL, settings: settings, busy: false)
            
            try await toggleRetinaMode(bottleURL: bottleURL, toggle: settings.retinaMode)
            
            allBottles?[name] = newBottle
            completion(.success(newBottle))
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
            print(output.stringValue ?? "no output from shader cache purge")
            
            if error != nil {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Add Registry Key Method
    private static func addRegistryKey(bottleURL: URL, key: String, name: String, data: String, type: RegistryType) async throws {
        guard bottleExists(bottleURL: bottleURL) else { throw BottleDoesNotExistError() }
        
        try await command( // FIXME: errors may create problems later
            args: ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"],
            identifier: "regadd",
            bottleURL: bottleURL
        )
    }
    
    // MARK: - Query Registry Key Method
    private static func queryRegistryKey(bottleURL: URL, key: String, name: String, type: RegistryType, completion: @escaping (Result<String, Error>) -> Void) async {
        do {
            let output = try await command(
                args: ["reg", "query", key, "-v", name],
                identifier: "regquery",
                bottleURL: bottleURL
            )
            
            guard let lines = String(data: output.stdout, encoding: .utf8)?.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) else { completion(.failure(UnableToQueryRegistyError())); return }
            guard let line = lines.first(where: { $0.contains(type.rawValue) }) else { completion(.failure(UnableToQueryRegistyError())); return }
            let array = line.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard let value = array.last else { completion(.failure(UnableToQueryRegistyError())); return }
            
            completion(.success(String(value)))
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
    static func bottleExists(bottleURL: URL) -> Bool { // TODO: refactor
        return (try? files.contentsOfDirectory(atPath: bottleURL.path).contains("drive_c")) ?? false
    }
}
