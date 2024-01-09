//
//  LegendaryInterface.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 21/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation
import SwiftyJSON
import OSLog

// MARK: - Legendary Class
/**
 Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities.
 
 [Legendary GitHub Repository](https://github.com/derrod/legendary)
 */
class Legendary {
    
    /// For threadsafing and providing examples
    public static let placeholderGame: Game = .init(appName: "[unknown]", title: "game")
    
    // MARK: - Properties
    
    /// The file location for legendary's configuration files.
    static let configLocation = Bundle.appHome!.appending(path: "Config").path
    
    /// Logger instance for legendary.
    public static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "legendaryInterface")
    
    /// Cache for storing command outputs.
    private static var commandCache: [String: (stdout: Data, stderr: Data)] = .init()
    
    // MARK: runningCommands
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
    
    // MARK: - Methods
    
    // MARK: - Command Method
    /**
     Run a legendary command using the included legendary binary.
     
     - Parameters:
        - args: The command arguments.
        - useCache: Flag indicating whether to use cached output.
        - identifier: String to keep track of individual command functions. (originally UUID-based)
        - input: Optional input string for the command.
        - inputIf: Optional condition to be checked for in the output streams before input is appended.
        - asyncOutput: Optional closure that gets output appended to it immediately.
        - additionalEnvironmentVariables: Optional dictionary that may contain other environment variables you wish to run with a command.
     
     - Returns: A tuple containing stdout and stderr data.
     */
    static func command(
        args: [String],
        useCache: Bool,
        identifier: String,
        input: String? = nil,
        inputIf: InputIfCondition? = nil,
        asyncOutput: OutputHandler? = nil,
        additionalEnvironmentVariables: [String: String]? = nil
    ) async -> (stdout: Data, stderr: Data) {
        
        struct QueueContainer {
            let cache: DispatchQueue = DispatchQueue(label: "legendaryCommandCache")
            let command: DispatchQueue = DispatchQueue(label: "legendaryCommand", attributes: .concurrent)
        }
        
        let queue = QueueContainer()
        
        let commandKey = String(describing: args)
        
        if useCache, let cachedOutput = queue.cache.sync(execute: { commandCache[commandKey] }), !cachedOutput.stdout.isEmpty && !cachedOutput.stderr.isEmpty {
            log.debug("Cached, returning.")
            Task(priority: .background) {
                _ = await run()
                log.debug("New cache appended.")
            }
            log.debug("Cache returned.")
            return cachedOutput
        } else {
            log.debug("\( useCache ? "Building new cache" : "Cache disabled for this task." )")
            return await run()
        }
        
        // MARK: - Run Method
        @Sendable
        func run() async -> (stdout: Data, stderr: Data) {
            let task = Process()
            task.executableURL = URL(filePath: Bundle.main.path(forResource: "legendary/cli", ofType: nil)!)
            
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
            
            // initialise legendary and config env
            task.standardError = pipe.stderr
            task.standardOutput = pipe.stdout
            task.standardInput = input != nil ? pipe.stdin : nil
            
            task.arguments = args
            
            var defaultEnvironmentVariables = ["LEGENDARY_CONFIG_PATH": configLocation]
            if let additionalEnvironmentVariables = additionalEnvironmentVariables {
                defaultEnvironmentVariables.merge(additionalEnvironmentVariables) { (_, new) in new }
            }
            task.environment = defaultEnvironmentVariables
            
            let fullCommand = "\((defaultEnvironmentVariables.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
            
            log.debug("executing \(fullCommand)")
            
            // MARK: Asynchronous stdout Appending
            queue.command.async(qos: .utility) {
                Task(priority: .high) {
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
            queue.command.async(qos: .utility) {
                Task(priority: .high) {
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
                runningCommands[identifier] = task
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
                switch true {
                case stderrString.contains("DEBUG:"):
                    log.debug("\(stderrString)")
                case stderrString.contains("INFO:"):
                    log.info("\(stderrString)")
                case stderrString.contains("WARNING:"):
                    log.warning("\(stderrString)")
                case stderrString.contains("ERROR:"):
                    log.error("\(stderrString)")
                case stderrString.contains("CRITICAL:"):
                    log.critical("\(stderrString)")
                default:
                    log.log("\(stderrString)")
                }
            } else {
                log.warning("empty stderr recieved from [\(commandKey)]")
            }
            
            if let stdoutString = String(data: output.stdout, encoding: .utf8) {
                if !stdoutString.isEmpty {
                    log.debug("\(stdoutString)")
                }
            } else {
                log.warning("empty stdout recieved from [\(commandKey)]")
            }
            
            queue.cache.sync { commandCache[commandKey] = output }
            
            return output
        }
    }
    
    // MARK: - Stop Command Method
    /**
     Stops the execution of a command based on its identifier.
     
     - Parameter identifier: The unique identifier of the command to be stopped.
     */
    static func stopCommand(identifier: String) {
        if let task = runningCommands[identifier] {
            task.terminate()
            runningCommands.removeValue(forKey: identifier)
        } else {
            log.error("Bad identifer, unable to stop command execution.")
        }
    }
    
    // MARK: - Base Path Property
    /**
     The file location for legendary's configuration files.
     
     This property represents the base path for games.
     */
    var basePath: URL? {
        get {
            if let value = defaults.object(forKey: "gamesPath") as? URL {
                return value
            } else { return Bundle.appGames }
        }
        set { defaults.set(newValue, forKey: "gamesPath") }
    }
    
    // MARK: - Install Method
    /**
     Installs, updates, or repairs games using legendary.
     
     - Parameters:
        - game: The game's `app_name`.
        - optionalPacks: Optional packs to install along with the base game.
        - basePath: A custom path for the game to install to.
        - gameFolder: The folder where the game should be installed.
        - platform: The platform for which the game should be installed.
     
     - Throws: A `NotSignedInError` or an `InstallationError`.
     */
    static func install(
        game: Game,
        platform: GamePlatform,
        type: InstallationType = .install,
        optionalPacks: [String]? = nil,
        basePath: URL? = /*defaults.object(forKey: "gamesPath") as? URL ??*/ Bundle.appGames, // TODO: userdefaults implementation
        gameFolder: URL? = nil
    ) async throws {
        guard signedIn() else { throw NotSignedInError() }
        // TODO: data lock handling
        
        let variables: VariableManager = .shared
        var errorThrownExternally: Error?
        
        var argBuilder = [
            "-y",
            "install",
            type == .repair ? "--repair" : nil,
            type == .update ? "--update-only": nil
        ]
            .compactMap { $0 }
        
        if type == .install { // MARK: Install-only arguments
            switch platform {
            case .macOS:
                argBuilder += ["--platform", "Mac"]
            case .windows:
                argBuilder += ["--platform", "Windows"]
            }
            
            if let basePath = basePath, files.fileExists(atPath: basePath.path) {
                argBuilder += ["--base-path", basePath.absoluteString]
            }
            
            if let gameFolder = gameFolder, files.fileExists(atPath: gameFolder.path) {
                argBuilder += ["--game-folder", gameFolder.absoluteString]
            }
        }
        
        var installStatus: [String: [String: Any]] = .init() // MARK: installStatus
        var verificationStatus: [String: Double] = .init()
        
        _ = await command(
            args: argBuilder + [game.appName],
            useCache: false,
            identifier: "install",
            input: "\(Array(optionalPacks ?? .init()).joined(separator: ", "))\n",
            inputIf: .init(
                stream: .stdout,
                string: "Additional packs [Enter to confirm]:"
            ),
            asyncOutput: .init(
                stdout: { output in
                    output.enumerateLines { line, _ in
                        if line.contains("Failure:") {
                            errorThrownExternally = InstallationError(String(line.trimmingPrefix(" ! Failure: ")))
                        } else if line.contains("Verification progress:") {
                            variables.setVariable("verifying", value: game) // FIXME: may cause lag when verifying due to rapid, repeated updating
                            if let regex = try? NSRegularExpression(pattern: #"Verification progress: (\d+)/(\d+) \((\d+\.\d+)%\) \[(\d+\.\d+) MiB/s\]"#),
                               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                                verificationStatus["verifiedFiles"] = Double((line as NSString).substring(with: match.range(at: 1)))
                                verificationStatus["totalFiles"] = Double((line as NSString).substring(with: match.range(at: 2)))
                                verificationStatus["percentage"] = Double((line as NSString).substring(with: match.range(at: 3))) // %
                                verificationStatus["speed"] = Double((line as NSString).substring(with: match.range(at: 4))) // MiB/s
                                
                                if verificationStatus["percentage"] == 100 {
                                    verificationStatus.removeAll()
                                    variables.removeVariable("verifying")
                                }
                                
                                variables.setVariable("verificationStatus", value: verificationStatus)
                            }
                        }
                    }
                },
                stderr: { output in
                    output.enumerateLines { line, _ in
                        if line.contains("[DLManager] INFO:") {
                            if !line.contains("All done! Download manager quitting...") { // do not add ellipses here
                                variables.setVariable("installing", value: game)
                                
                                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                                if let regex = try? NSRegularExpression(pattern: #"Progress: (\d+\.\d+)% \((\d+)/(\d+)\), Running for (\d+:\d+:\d+), ETA: (\d+:\d+:\d+)"#),
                                   let match = regex.firstMatch(in: line, range: range) {
                                    installStatus["progress"] = [
                                        "percentage": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                        "downloaded": Int(line[Range(match.range(at: 2), in: line)!]) ?? 0,
                                        "total": Int(line[Range(match.range(at: 3), in: line)!]) ?? 0,
                                        "runtime": line[Range(match.range(at: 4), in: line)!],
                                        "eta": line[Range(match.range(at: 5), in: line)!]
                                    ]
                                } else if let regex = try? NSRegularExpression(pattern: #"Downloaded: ([\d.]+) \w+, Written: ([\d.]+) \w+"#),
                                          let match = regex.firstMatch(in: line, range: range) {
                                    installStatus["download"] = [ // MiB | 1 MB = (10^6/2^20) MiB
                                        "downloaded": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                        "written": Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                    ]
                                } else if let regex = try? NSRegularExpression(pattern: #"Cache usage: ([\d.]+) \w+, active tasks: (\d+)"#),
                                          let match = regex.firstMatch(in: line, range: range) {
                                    installStatus["downloadCache"] = [
                                        "usage": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0, // MiB
                                        "activeTasks": Int(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                    ]
                                } else if let regex = try? NSRegularExpression(pattern: #"\+ Download\s+- ([\d.]+) \w+/\w+ \(raw\) / ([\d.]+) \w+/\w+ \(decompressed\)"#),
                                          let match = regex.firstMatch(in: line, range: range) {
                                    installStatus["downloadAdvanced"] = [ // MiB/s
                                        "raw": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                        "decompressed": Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                    ]
                                } else if let regex = try? NSRegularExpression(pattern: #"\+ Disk\s+- ([\d.]+) \w+/\w+ \(write\) / ([\d.]+) \w+/\w+ \(read\)"#),
                                          let match = regex.firstMatch(in: line, range: range) {
                                    installStatus["downloadDisk"] = [ // MiB/s
                                        "write": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                        "read": Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                    ]
                                }
                                if line.contains("All done! Download manager quitting...") { // do not add ellipses here
                                    installStatus.removeAll()
                                } else {
                                    variables.setVariable("installStatus", value: installStatus)
                                }
                            } else {
                                variables.removeVariable("installing")
                            }
                        }
                    }
                }
            )
        )
        
        // This exists because throwing an error inside of an OutputHandler isn't possible directly.
        // Throwing an error directly to install() is preferable.
        if let error = errorThrownExternally { variables.removeVariable("installing"); throw error }
    }
    
    static func launch(game: Game, bottle: URL) async throws { // TODO: be able to tell when game is runnning
        guard try Legendary.getInstalledGames().contains(game) else {
            log.error("Unable to launch game, not installed or missing") // TODO: add alert in unified alert system
            throw GameDoesNotExistError(game)
        }
        
        guard Libraries.isInstalled() else { throw Libraries.NotInstalledError() }
        guard Wine.prefixExists(at: bottle) else { throw Wine.PrefixDoesNotExistError() }
        
        VariableManager.shared.setVariable("launching_\(game.appName)", value: true)
        defaults.set(try PropertyListEncoder().encode(game), forKey: "recentlyPlayed")
        
        _ = await command(
            args: [
                "launch",
                game.appName,
                "--wine",
                Libraries.directory.appending(path: "Wine/bin/wine64").path
            ],
            useCache: false,
            identifier: "launch_\(game.appName)",
            additionalEnvironmentVariables: ["WINEPREFIX": bottle.path]
        )
        
        VariableManager.shared.setVariable("launching_\(game.appName)", value: false)
    }
    
    /*
     static func play(game: Game, bottle: WhiskyInterface.Bottle) async {
     var environmentVariables: [String: String] = Dictionary()
     environmentVariables["WINEPREFIX"] = "/Users/blackxfiied/Library/Containers/xyz.blackxfiied.Mythic/Bottles/Test" // in containers, libraries in applicaiton support
     
     if let dxvkConfig = bottle.metadata["dxvkConfig"] as? [String: Any] {
     if let dxvk = dxvkConfig["dxvk"] as? Bool {
     print("dxvk: \(dxvk)")
     }
     if let dxvkAsync = dxvkConfig["dxvkAsync"] as? Bool {
     print("dxvkAsync: \(dxvkAsync)")
     }
     if let dxvkHud = dxvkConfig["dxvkHud"] as? [String: Any] {
     if let fps = dxvkHud["fps"] as? [String: Any] {
     print("fps: \(fps)")
     }
     }
     }
     
     if let fileVersion = bottle.metadata["fileVersion"] as? [String: Any] {
     if let major = fileVersion["major"] as? Int {
     print("fileVersion major: \(major)")
     }
     if let minor = fileVersion["minor"] as? Int {
     print("fileVersion minor: \(minor)")
     }
     }
     
     if let metalConfig = bottle.metadata["metalConfig"] as? [String: Any] {
     if let metalHud = metalConfig["metalHud"] as? Bool,
     metalHud == true {
     environmentVariables["MTL_HUD_ENABLED"] = "1"
     }
     if let metalTrace = metalConfig["metalTrace"] as? Bool {
     print("metal trace: \(metalTrace)")
     }
     }
     
     if let wineConfig = bottle.metadata["wineConfig"] as? [String: Any] {
     if let msync = wineConfig["msync"] as? Bool,
     msync == true {
     environmentVariables["WINEMSYNC"] = "1"
     }
     
     if let windowsVersion = wineConfig["windowsVersion"] as? String {
     print("windowsVersion: \(windowsVersion.trimmingPrefix("win"))")
     }
     
     if let wineVersion = wineConfig["wineVersion"] as? [String: Any] {
     if let major = wineVersion["major"] as? Int {
     print("wineVersion major: \(major)")
     }
     if let minor = wineVersion["minor"] as? Int {
     print("wineVersion minor: \(minor)")
     }
     if let patch = wineVersion["patch"] as? Int {
     print("wineVersion patch: \(patch)")
     }
     }
     }
     
     _ = await command(args: [
     "launch",
     game.appName,
     "--wine",
     "/Users/blackxfiied/Library/Application Support/com.isaacmarovitz.Whisky/Libraries/Wine/bin/wine64"
     ]
     .compactMap { $0 },
     useCache: false,
     additionalEnvironmentVariables: environmentVariables
     )
     }
     */
    
    // TODO: DocC
    static func getGamePlatform(game: Game) throws -> GamePlatform {
        let platform = try? JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))[game.appName]["platform"].string
        if platform == "Mac" {
            return .macOS
        } else if platform == "Windows" {
            return .windows
        } else {
            throw UnableToGetPlatformError()
        }
        
    }
    
    // TODO: DocC
    static func needsUpdate(game: Game) -> Bool {
        var needsUpdate: Bool = false
        
        do {
            let metadata = try getGameMetadata(game: game)
            let installed = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))
            
            if let installedVersion = installed[game.appName]["version"].string,
               let platform = installed[game.appName]["platform"].string,
               let upstreamVersion = metadata?["asset_infos"][platform]["build_version"].string {
                if upstreamVersion != installedVersion {
                    needsUpdate = true
                }
            } else {
                log.error("Unable to compare upstream and installed version of game \"\(game.title)\".")
            }
        } catch {
            log.error("Unable to fetch if \(game.title) needs an update: \(error)")
        }
        
        return needsUpdate
    }
    
    // MARK: - Clear Command Cache Method
    /**
     Wipes legendary's command cache. This will slow some legendary commands until the cache is rebuilt.
     */
    static func clearCommandCache() {
        commandCache = .init()
        log.notice("Cleared legendary command cache.")
    }
    
    // MARK: - Who Am I Method
    /**
     Queries the user that is currently signed into epic games.
     This command has no delay.
     
     - Returns: The user's account information as a `String`.
     */
    static func whoAmI() -> String {
        let userJSONFileURL = URL(filePath: "\(configLocation)/user.json")
        
        guard
            files.fileExists(atPath: userJSONFileURL.path),
            let json = try? JSON(data: Data(contentsOf: userJSONFileURL))
        else { return "Nobody" }
        
        return String(describing: json["displayName"])
    }
    
    // MARK: - Signed In Method
    /**
     Boolean verifier for the user's epic games signin state.
     This command has no delay.
     
     - Returns: `true` if the user is signed in, otherwise `false`.
     */
    static func signedIn() -> Bool { return whoAmI() != "Nobody" }
    
    // MARK: - Get Installed Games Method
    /**
     Retrieve installed games from epic games services.
     
     - Returns: A dictionary containing ``Legendary.Game`` objects.
     - Throws: A ``NotSignedInError``.
     */
    static func getInstalledGames() throws -> [Game] {
        guard signedIn() else { throw NotSignedInError() }
        
        let installedJSONFileURL: URL = URL(filePath: "\(configLocation)/installed.json")
        
        guard let installedData = try? Data(contentsOf: installedJSONFileURL) else {
            throw FileLocations.FileDoesNotExistError(installedJSONFileURL)
        }
        
        guard let installedGames = try JSONSerialization.jsonObject(with: installedData) as? [String: [String: Any]] else { // stupid json dependency is stupid
            return .init()
        }
        
        var apps: [Game] = .init()
        
        for (appName, gameInfo) in installedGames {
            if let title = gameInfo["title"] as? String {
                apps.append(Game(appName: appName, title: title))
            }
        }
        
        return apps
    }
    
    // MARK: - Get Installable Method
    /**
     Retrieve installed games from epic games services.
     
     - Returns: An `Array` of ``Game`` objects.
     */
    static func getInstallable() async throws -> [Game] { // TODO: use files in Config/metadata and use command to update in the background [IMPORTANT TO UPD IN BKG]
        guard signedIn() else { throw NotSignedInError() }
        
        guard let json = try? await JSON(data: command(
            args: [
                "list",
                "--platform",
                "Windows",
                "--third-party",
                "--json"
            ],
            useCache: true,
            identifier: "getInstallable"
        ).stdout) else {
            return .init()
        }
        
        return extractAppNamesAndTitles(from: json)
    }
    
    // MARK: - Get Game Metadata Method
    /**
     Retrieve game metadata as a JSON.
     
     - Parameter game: A ``Game`` object.
     - Throws: A ``DoesNotExistError`` if the metadata directory doesn't exist.
     - Returns: An optional `JSON` with either the metadata or `nil`.
     */
    static func getGameMetadata(game: Game) throws -> JSON? {
        let metadataDirectoryString = "\(configLocation)/metadata"
        
        guard let metadataDirectoryContents = try? files.contentsOfDirectory(atPath: metadataDirectoryString) else {
            throw FileLocations.FileDoesNotExistError(URL(filePath: metadataDirectoryString))
        }
        
        if let metadataFileName = metadataDirectoryContents.first(where: {
            $0.hasSuffix(".json") && $0.contains(game.appName)
        }),
           let data = try? Data(contentsOf: URL(filePath: "\(metadataDirectoryString)/\(metadataFileName)")),
           let json = try? JSON(data: data) {
            return json
        }
        
        return nil
    }
    
    /**
     Retrieves game thumbnail image from legendary's downloaded metadata.
     
     - Parameters:
        - of: The game to fetch the thumbnail of.
        - type: The aspect ratio of the image to fetch the thumbnail of.
     
     - Returns: The WebURL of the retrieved image.
     */
    static func getImage(of game: Game, type: ImageType) async -> String {
        let metadata = try? getGameMetadata(game: game)
        var imageURL: String = .init()
        
        if let keyImages = metadata?["metadata"]["keyImages"].array {
            for image in keyImages {
                if type == .normal {
                    if image["type"] == "DieselGameBox" {
                        imageURL = image["url"].stringValue
                    }
                } else if type == .tall {
                    if image["type"] == "DieselGameBoxTall" {
                        imageURL = image["url"].stringValue
                    }
                }
            }
        }
        
        return imageURL
    }

    // MARK: - Get Images Method
    /**
     Get game images with "DieselGameBox" metadata.
     
     - Parameter imageType: The type of images to retrieve (normal or tall).
     - Throws: A ``NotSignedInError``.
     - Returns: A `Dictionary` with app names as keys and image URLs as values.
     */
    @available(*, message: "Soon to be deprecated and replaced by `getImage`")
    static func getImages(imageType: ImageType) async throws -> [String: String] {
        guard signedIn() else { throw NotSignedInError() }
        
        guard let json = try? await JSON(data: command(
            args: [
                "list",
                "--platform",
                "Windows",
                "--third-party",
                "--json"
            ],
            useCache: true,
            identifier: "getImages"
        ).stdout) else {
            return .init()
        }
        
        var urls: [String: String] = .init()
        
        for game in json {
            let appName = String(describing: game.1["app_name"])
            if let keyImages = game.1["metadata"]["keyImages"].array {
                var image: [JSON] = .init()
                
                switch imageType {
                case .normal:
                    image = keyImages.filter { $0["type"].string == "DieselGameBox" }
                case .tall:
                    image = keyImages.filter { $0["type"].string == "DieselGameBoxTall" }
                }
                
                if let imageURL = image.first?["url"].string {
                    urls[appName] = imageURL
                }
            }
        }
        
        return urls
    }
    
    // MARK: - Is Alias Method
    /**
     Checks if an alias of a game exists.
     
     - Parameter game: Any `String` that may return an aliased output.
     - Returns: A tuple containing the outcome of the check, and which game it's an alias of (is an app\_name).
     */
    static func isAlias(game: String) throws -> (Bool?, of: String?) {
        guard signedIn() else { throw NotSignedInError() }
        
        let aliasesJSONFileURL: URL = URL(filePath: "\(configLocation)/aliases.json")
        
        guard let aliasesData = try? Data(contentsOf: aliasesJSONFileURL) else {
            throw FileLocations.FileDoesNotExistError(aliasesJSONFileURL)
        }
        
        guard let json = try? JSON(data: aliasesData) else {
            return (nil, of: nil)
        }
        
        for (appName, dict) in json {
            if appName == game || dict.compactMap({ $0.1.rawString() }).contains(game) {
                return (true, of: appName)
            }
        }
        
        return (nil, of: nil)
    }
    
    // MARK: - Deprecated Methods
    /**
     Retrieve the game's app\_name from the game's title.
     
     - Parameter appTitle: The title of the game.
     - Returns: The app name of the game.
     */
    @available(*, deprecated, message: "Made redundant by Legendary.Game")
    static func getAppNameFromTitle(appTitle: String) async -> String? { // TODO: full removal before launch
        guard signedIn() else { return String() }
        let json = try? await JSON(data: command(args: ["info", appTitle, "--json"], useCache: true, identifier: "getAppNameFromTitle").stdout)
        return json?["game"]["app_name"].stringValue
    }
    
    /**
     Retrieve the game's title from the game's app\_name.
     
     - Parameter appName: The app name of the game.
     - Returns: The title of the game.
     */
    @available(*, deprecated, message: "Made redundant by Legendary.Game")
    static func getTitleFromAppName(appName: String) async -> String? { // TODO: full removal before launch
        guard signedIn() else { return String() }
        let json = try? await JSON(data: command(args: ["info", appName, "--json"], useCache: true, identifier: "getTitleFromAppName").stdout)
        return json?["game"]["title"].stringValue
    }
    
    // MARK: - Extract App Names and Titles Method
    /**
     Well, what do you think it does?
     */
    private static func extractAppNamesAndTitles(from json: JSON?) -> [Game] {
        var games: [Game] = .init()
        
        if let json = json {
            for game in json {
                games.append(
                    Game(
                        appName: game.1["app_name"].string ?? .init(),
                        title: game.1["app_title"].string ?? .init()
                    )
                )
            }
        }
        
        return games
    }
}
