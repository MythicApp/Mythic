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
import UserNotifications

// MARK: - Legendary Class
/**
 Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities.
 
 [Legendary GitHub Repository](https://github.com/derrod/legendary)
 */
class Legendary {
    
    // MARK: - Properties
    
    /// The file location for legendary's configuration files.
    static let configLocation = Bundle.appHome!.appending(path: "Config").path
    
    /// Logger instance for legendary.
    public static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "legendaryInterface")
    
    /// Cache for storing command outputs.
    private static var commandCache: [String: (stdout: Data, stderr: Data)] = .init()
    
    private static var downloadQueue: [Mythic.Game] = .init()
    
    // MARK: runningCommands
    private static var _runningCommands: [String: Process] = .init()
    private static let _runningCommandsQueue = DispatchQueue(label: "legendaryRunningCommands", attributes: .concurrent)
    
    /// Dictionary to monitor running commands and their identifiers.
    private static var runningCommands: [String: Process] {
        get {
            _runningCommandsQueue.sync {
                return _runningCommands
            }
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
    @discardableResult
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
        }
        
        let queue = QueueContainer()
        
        let commandKey = String(describing: args)
        
        if useCache, let cachedOutput = queue.cache.sync(execute: { commandCache[commandKey] }), !cachedOutput.stdout.isEmpty && !cachedOutput.stderr.isEmpty {
            log.debug("Cached, returning.")
            Task(priority: .background) {
                await run()
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
        @discardableResult
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
            task.qualityOfService = .userInitiated
            
            log.debug("Executing: \(fullCommand)")
            
            // MARK: Asynchronous stdout Appending
            Task(priority: .utility) {
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
            
            // MARK: Asynchronous stderr Appending
            Task(priority: .utility) {
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
            
            if let input = input, !input.isEmpty && inputIf == nil {
                if let inputData = input.data(using: .utf8) {
                    pipe.stdin.fileHandleForWriting.write(inputData)
                    pipe.stdin.fileHandleForWriting.closeFile()
                }
            }
            
            // MARK: Run
            do {
                defer { runningCommands.removeValue(forKey: identifier) }
                runningCommands[identifier] = task // WHY
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
                case stderrString.contains("WARN:"):
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
     Stops the execution of a command based on its identifier. (SIGTERM)
     
     - Parameter identifier: The unique identifier of the command to be stopped.
     */
    static func stopCommand(identifier: String) { // TODO: pause and replay downloads using task.suspend() and task.resume()
        if let task = runningCommands[identifier] {
            task.interrupt() // SIGTERM
            runningCommands.removeValue(forKey: identifier)
        } else {
            log.error("Unable to stop Legendary command: Bad identifier.")
        }
    }
    
    /// Stops the execution of all commands.
    static func stopAllCommands() { runningCommands.keys.forEach { stopCommand(identifier: $0) } }
    
    // MARK: Install Method
    /**
     Installs, updates, or repairs games using legendary.
     
     - Parameters:
     - game: The game's `app_name`. (referred to as id)
     - platform: The game's platform.
     - type: The nature of the game modification.
     - optionalPacks: Optional packs to install along with the base game.
     - baseURL: A custom ``URL`` for the game to install to.
     - gameFolder: The folder where the game should be installed.
     - priority: Whether the game should interrupt the currently queued game installation.
     
     - Throws: A `NotSignedInError` or an `InstallationError`.
     */
    static func install(
        game: Mythic.Game,
        platform: GamePlatform,
        type: GameModificationType = .install,
        optionalPacks: [String]? = nil,
        baseURL: URL? = defaults.url(forKey: "installBaseURL"),
        gameFolder: URL? = nil,
        priority: Bool = false
    ) async throws {
        try await install(
            args: .init(
                game: game,
                platform: platform,
                type: type,
                optionalPacks: optionalPacks,
                baseURL: baseURL,
                gameFolder: gameFolder
            ), priority: priority
        )
    }
    
    // MARK: - Overloaded Install Method
    /// - Parameters:
    ///    - args: Installation arguments
    static func install(args: GameOperation.InstallArguments, priority: Bool = false) async throws {
        guard signedIn() else { throw NotSignedInError() }
        guard args.game.type == .epic else { throw IsNotLegendaryError() }
        // guard args.type != .uninstall else { do {/* Add uninstallation support via dialog */}; return }
        
        // TODO: data lock handling
        
        let variables: VariableManager = .shared
        let operation: GameOperation = .shared
        var errorThrownExternally: Error?
        
        var argBuilder = [
            "-y",
            "install",
            args.game.id,
            args.type == .repair ? "--repair" : nil,
            args.type == .update ? "--update-only": nil
        ] .compactMap { $0 }
        
        if args.type == .install { // Install-only arguments
            switch args.platform {
            case .macOS:
                argBuilder += ["--platform", "Mac"]
            case .windows:
                argBuilder += ["--platform", "Windows"]
            }
            
            // Legendary will download elsewhere if none are specified
            if let baseURL = args.baseURL, files.fileExists(atPath: baseURL.path) {
                argBuilder += ["--base-path", baseURL.path(percentEncoded: false)]
            }
            
            if let gameFolder = args.gameFolder, files.fileExists(atPath: gameFolder.path) {
                argBuilder += ["--game-folder", gameFolder.absoluteString]
            }
        }
        
        var verificationStatus: [String: Double] = .init()
        var status: [String: [String: Any]] = .init()
        
        let progressRegex = #"Progress: (\d+\.\d+)% \((\d+)/(\d+)\), Running for (\d+:\d+:\d+), ETA: (\d+:\d+:\d+)"#
        let downloadedRegex = #"Downloaded: ([\d.]+) \w+, Written: ([\d.]+) \w+"#
        let cacheUsageRegex = #"Cache usage: ([\d.]+) \w+, active tasks: (\d+)"#
        let downloadAdvancedRegex = #"\+ Download\s+- ([\d.]+) \w+/\w+ \(raw\) / ([\d.]+) \w+/\w+ \(decompressed\)"#
        let downloadDiskRegex = #"\+ Disk\s+- ([\d.]+) \w+/\w+ \(write\) / ([\d.]+) \w+/\w+ \(read\)"#
        
        func match(regex: String, line: String) -> NSTextCheckingResult? {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let regex = try? NSRegularExpression(pattern: regex)
            return regex?.firstMatch(in: line, range: range)
        }
        
        await command(
            args: argBuilder,
            useCache: false,
            identifier: "install",
            input: "\(Array(args.optionalPacks ?? .init()).joined(separator: ", "))" + "\n",
            inputIf: .init(
                stream: .stdout,
                string: "Additional packs [Enter to confirm]:"
            ),
            asyncOutput: .init(
                stdout: { output in
                    output.enumerateLines { line, _ in
                        if line.contains("Failure:") {
                            /*
                             FIXME: Example output of error
                             Installation requirements check returned the following results:
                             - Warning: This game requires an ownership verification token and likely uses Denuvo DRM.
                             ! Failure: Not enough available disk space! 12.05 GiB < 12.55 GiB
                             */
                            errorThrownExternally = InstallationError(message: String(line.trimmingPrefix(" ! Failure: ")))
                        } else if line.contains("Verification progress:") {
                            variables.setVariable("verifying", value: args.game) // FIXME: may cause lag when verifying due to rapid, repeated updating
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
                        guard line.contains("[DLManager] INFO:") else { return }
                        
                        if line.contains("All done! Download manager quitting...") {
                            return
                        }
                        
                        if let match = match(regex: progressRegex, line: line) {
                            status["progress"] = [
                                "percentage": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                "downloaded": Int(line[Range(match.range(at: 2), in: line)!]) ?? 0,
                                "total": Int(line[Range(match.range(at: 3), in: line)!]) ?? 0,
                                "runtime": line[Range(match.range(at: 4), in: line)!],
                                "eta": line[Range(match.range(at: 5), in: line)!]
                            ]
                        } else if let match = match(regex: downloadedRegex, line: line) {
                            status["download"] = [
                                "downloaded": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                "written": Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                            ]
                        } else if let match = match(regex: cacheUsageRegex, line: line) {
                            status["downloadCache"] = [
                                "usage": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                "activeTasks": Int(line[Range(match.range(at: 2), in: line)!]) ?? 0
                            ]
                        } else if let match = match(regex: downloadAdvancedRegex, line: line) {
                            status["downloadAdvanced"] = [
                                "raw": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                "decompressed": Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                            ]
                        } else if let match = match(regex: downloadDiskRegex, line: line) {
                            status["downloadDisk"] = [
                                "write": Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                "read": Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                            ]
                        }
                        
                        DispatchQueue.main.async { // FIXME: might cause lag
                            operation.current?.status = status
                            GameOperation.log.debug("""
                            \n-- INSTALLATION --\n
                            operation.current.status is being updated with: \(status).
                            operation.current.args is currently reading: \(String(describing: operation.current?.args)).
                            operation.current.args is \(operation.current?.args.game == args.game ? .init() : "not ")the same as the current installation's args.
                            the download queue currently reads: \(operation.queue)
                            """)
                        }
                        
                    }
                }
            )
        )
        
        // This exists because throwing an error inside of an OutputHandler isn't possible directly.
        // Throwing an error directly to install() is preferable
        // FIXME: withCheckedThrowingContinuation may fix this problem
        if let error = errorThrownExternally { throw error }
    }
    
    static func move(game: Mythic.Game, newPath: String) async throws {
        if let oldPath = try getGamePath(game: game) {
            guard files.isWritableFile(atPath: oldPath) else { throw FileLocations.FileNotModifiableError(.init(filePath: oldPath)) }
            try files.moveItem(atPath: oldPath, toPath: "\(newPath)/\(oldPath.components(separatedBy: "/").last!)")
            await command(
                args: ["move", game.id, newPath, "--skip-move"],
                useCache: false,
                identifier: "moveGame"
            )
            
            try await notifications.add(
                .init(identifier: UUID().uuidString,
                      content: {
                          let content = UNMutableNotificationContent()
                          content.title = "Finished moving \"\(game.title)\"."
                          content.title = "\"\(game.title)\" can now be found at \(URL(filePath: newPath).prettyPath())"
                          return content
                      }(),
                      trigger: nil)
            )
            
        }
    }
    
    static func signIn(authKey: String) async -> Bool {
        let command = await Legendary.command(
            args: ["auth", "--code", authKey],
            useCache: false,
            identifier: "signIn"
        )
        
        if let stderr = String(data: command.stderr, encoding: .utf8) {
            return stderr.contains("Successfully logged in as")
        }
        
        return false
    }
    
    /**
     Launches games.
     
     - Parameters:
     - game: The game to launch.
     - bottle: The
     */
    static func launch(game: Mythic.Game, online: Bool) async throws { // TODO: be able to tell when game is runnning
        guard try Legendary.getInstalledGames().contains(game) else {
            log.error("Unable to launch game, not installed or missing") // TODO: add alert in unified alert system
            throw GameDoesNotExistError(game)
        }
        
        guard Libraries.isInstalled() else { throw Libraries.NotInstalledError() }
        guard let bottle = Wine.allBottles?[game.bottleName] else { throw Wine.BottleDoesNotExistError() }
        
        DispatchQueue.main.async {
            GameOperation.shared.launching = game
        }
        
        defaults.set(try PropertyListEncoder().encode(game), forKey: "recentlyPlayed")
        
        var args = [
            "launch",
            game.id,
            needsUpdate(game: game) ? "--skip-version-check" : nil,
            online ? nil : "--offline"
        ] .compactMap { $0 }
        
        var environmentVariables = ["MTL_HUD_ENABLED": bottle.settings.metalHUD ? "1" : "0"]
        
        if game.platform == .windows {
            args += ["--wine", Libraries.directory.appending(path: "Wine/bin/wine64").path]
            environmentVariables["WINEPREFIX"] = bottle.url.path(percentEncoded: false)
            environmentVariables["WINEMSYNC"] = bottle.settings.msync ? "1" : "0"
        }
        
        await command(args: args, useCache: false, identifier: "launch_\(game.id)", additionalEnvironmentVariables: environmentVariables)
        
        DispatchQueue.main.async {
            GameOperation.shared.launching = nil
        }
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
     game.id,
     "--wine",
     "/Users/blackxfiied/Library/Application Support/com.isaacmarovitz.Whisky/Libraries/Wine/bin/wine64"
     ]
     .compactMap { $0 },
     useCache: false,
     additionalEnvironmentVariables: environmentVariables
     )
     }
     */
    
    // MARK: Get Game Platform Method
    /**
     Determines the platform of the game.
     
     - Parameter platform: The platform of the game.
     - Throws: `UnableToGetPlatformError` if the platform is not "Mac" or "Windows".
     - Returns: The platform of the game as a `Platform` enum.
     */
    static func getGamePlatform(game: Mythic.Game) throws -> GamePlatform {
        guard game.type == .epic else { throw IsNotLegendaryError() }
        
        let platform = try? JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))[game.id]["platform"].string
        if platform == "Mac" {
            return .macOS
        } else if platform == "Windows" {
            return .windows
        } else {
            throw UnableToGetPlatformError()
        }
        
    }
    
    // MARK: Needs Update Method
    /**
     Determines if the game needs an update.
     
     - Parameter game: The game to check for updates.
     - Returns: A boolean indicating whether the game needs an update.
     */
    static func needsUpdate(game: Mythic.Game) -> Bool {
        var needsUpdate: Bool = false
        
        do {
            let metadata = try getGameMetadata(game: game)
            let installed = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))
            
            if let installedVersion = installed[game.id]["version"].string,
               let platform = installed[game.id]["platform"].string,
               let upstreamVersion = metadata?["asset_infos"][platform]["build_version"].string {
                if upstreamVersion != installedVersion {
                    needsUpdate = true
                }
            } else {
                log.error("Unable to compare upstream and installed version of game \"\(game.title)\".")
            }
        } catch {
            log.error("Unable to fetch if \(game.title) needs an update: \(error.localizedDescription)")
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
     
     - Returns: A dictionary containing ``Game`` objects.
     - Throws: A ``NotSignedInError``.
     */
    static func getInstalledGames() throws -> [Mythic.Game] {
        guard signedIn() else { throw NotSignedInError() }
        
        let installedJSONFileURL: URL = URL(filePath: "\(configLocation)/installed.json")
        
        guard let installedData = try? Data(contentsOf: installedJSONFileURL) else {
            throw FileLocations.FileDoesNotExistError(installedJSONFileURL)
        }
        
        guard let installedGames = try JSONSerialization.jsonObject(with: installedData) as? [String: [String: Any]] else { // stupid json dependency is stupid
            return .init()
        }
        
        var apps: [Mythic.Game] = .init()
        
        for (id, gameInfo) in installedGames {
            if let title = gameInfo["title"] as? String {
                apps.append(Mythic.Game(type: .epic, title: title, id: id))
            }
        }
        
        return apps
    }
    
    static func getGamePath(game: Mythic.Game) throws -> String? { // no need to throw if it returns nil
        guard signedIn() else { throw NotSignedInError() }
        guard game.type == .epic else { throw IsNotLegendaryError() }
        
        let installed = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))
        
        return installed[game.id]["install_path"].string
    }
    
    // MARK: - Get Installable Method
    /**
     Retrieve installed games from epic games services.
     
     - Returns: An `Array` of ``Game`` objects.
     */
    static func getInstallable() throws -> [Mythic.Game] {
        guard signedIn() else { throw NotSignedInError() }
        
        let metadata = "\(configLocation)/metadata"
        
        if let metadataContents = try? files.contentsOfDirectory(atPath: metadata),
           !metadataContents.isEmpty {
            Task(priority: .background) {
                await command(args: ["status"], useCache: false, identifier: "refreshMetadata")
            }
        } else {
            Task.sync(priority: .high) { // called during onboarding for speed
                await command(args: ["status"], useCache: false, identifier: "refreshMetadata")
            }
        }
        
        let games = try files.contentsOfDirectory(atPath: metadata).map { file -> Mythic.Game in
            let json = try JSON(data: .init(contentsOf: .init(filePath: "\(metadata)/\(file)")))
            return .init(type: .epic, title: json["app_title"].stringValue, id: json["app_name"].stringValue)
        }
        
        return games.sorted { $0.title < $1.title }
    }
    
    // MARK: - Get Game Metadata Method
    /**
     Retrieve game metadata as a JSON.
     
     - Parameter game: A ``Game`` object.
     - Throws: A ``DoesNotExistError`` if the metadata directory doesn't exist.
     - Returns: An optional `JSON` with either the metadata or `nil`.
     */
    static func getGameMetadata(game: Mythic.Game) throws -> JSON? {
        guard game.type == .epic else { throw IsNotLegendaryError() }
        let metadataDirectoryString = "\(configLocation)/metadata"
        
        guard let metadataDirectoryContents = try? files.contentsOfDirectory(atPath: metadataDirectoryString) else {
            throw FileLocations.FileDoesNotExistError(URL(filePath: metadataDirectoryString))
        }
        
        if let metadataFileName = metadataDirectoryContents.first(where: {
            $0.hasSuffix(".json") && $0.contains(game.id)
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
    static func getImage(of game: Mythic.Game, type: ImageType) -> String {
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
    @available(*, deprecated, message: "Deprecated by `getImage`")
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
            let id = String(describing: game.1["app_name"])
            if let keyImages = game.1["metadata"]["keyImages"].array {
                var image: [JSON] = .init()
                
                switch imageType {
                case .normal:
                    image = keyImages.filter { $0["type"].string == "DieselGameBox" }
                case .tall:
                    image = keyImages.filter { $0["type"].string == "DieselGameBoxTall" }
                }
                
                if let imageURL = image.first?["url"].string {
                    urls[id] = imageURL
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
        
        for (id, dict) in json {
            if id == game || dict.compactMap({ $0.1.rawString() }).contains(game) {
                return (true, of: id)
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
    @available(*, deprecated, message: "Made redundant by Game")
    static func getAppNameFromTitle(appTitle: String) async -> String? { // TODO: full removal before launch
        guard signedIn() else { return String() }
        let json = try? await JSON(data: command(args: ["info", appTitle, "--json"], useCache: true, identifier: "getAppNameFromTitle").stdout)
        return json?["game"]["app_name"].stringValue
    }
    
    /**
     Retrieve the game's title from the game's app\_name.
     
     - Parameter id: The app name of the game.
     - Returns: The title of the game.
     */
    @available(*, deprecated, message: "Made redundant by Game")
    static func getTitleFromAppName(id: String) async -> String? { // TODO: full removal before launch
        guard signedIn() else { return String() }
        let json = try? await JSON(data: command(args: ["info", id, "--json"], useCache: true, identifier: "getTitleFromAppName").stdout)
        return json?["game"]["title"].stringValue
    }
    
    // MARK: - Extract App Names and Titles Method
    /**
     Well, what do you think it does?
     */
    private static func extractAppNamesAndTitles(from json: JSON?) -> [Mythic.Game] {
        var games: [Mythic.Game] = .init()
        
        if let json = json {
            for game in json {
                games.append(
                    Mythic.Game(
                        type: .epic,
                        title: game.1["app_title"].string ?? .init(),
                        id: game.1["app_name"].string ?? .init()
                    )
                )
            }
        }
        
        return games
    }
}
