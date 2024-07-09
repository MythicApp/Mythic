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
import RegexBuilder

// MARK: - Legendary Class
/**
 Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities.
 
 [Legendary GitHub Repository](https://github.com/derrod/legendary)
 */
final class Legendary {
    
    // MARK: - Properties
    
    /// The file location for legendary's configuration files.
    static let configLocation = Bundle.appHome!.appending(path: "Config").path
    
    /// Logger instance for legendary.
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "legendaryInterface")
    
    /// Cache for storing command outputs.
    private static var commandCache: [String: (stderr: Data, stdout: Data)] = .init()
    
    private static var _runningCommands: [String: Process] = .init()
    private static let _runningCommandsQueue = DispatchQueue(label: "legendaryRunningCommands", attributes: .concurrent)
    
    /// Dictionary to monitor running commands and their identifiers.
    static var runningCommands: [String: Process] {
        get {
            _runningCommandsQueue.sync {
                return _runningCommands
            }
        }
        set {
            _runningCommandsQueue.async(flags: .barrier) {
                _runningCommands = newValue
            }
        }
    }
    
    // MARK: - Methods
    
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
    static func command(arguments args: [String], identifier: String, waits: Bool = true, input: ((String) -> String?)? = nil, environment: [String: String]? = nil, completion: @escaping (CommandOutput) -> Void) async throws {
        let task = Process()
        task.executableURL = URL(filePath: Bundle.main.path(forResource: "legendary/cli", ofType: nil)!)
        
        let stdin: Pipe = .init()
        let stderr: Pipe = .init()
        let stdout: Pipe = .init()
        
        task.standardInput = stdin
        task.standardError = stderr
        task.standardOutput = stdout
        
        var mutableArgs = args
        
        if !NetworkMonitor().isEpicAccessible {
            mutableArgs.append("--offline")
        }
        
        task.arguments = mutableArgs
        
        let constructedEnvironment = ["LEGENDARY_CONFIG_PATH": configLocation].merging(environment ?? .init(), uniquingKeysWith: { $1 })
        let terminalFormat = "\((constructedEnvironment.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
        task.environment = constructedEnvironment
        
        task.qualityOfService = .userInitiated
        
        let output: CommandOutput = .init() // weakly captured output tends to deallocate prematurely
        
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
    
    // MARK: - Stop Command Method
    /**
     Stops the execution of a command based on its identifier. (SIGTERM)
     
     - Parameter identifier: The unique identifier of the command to be stopped.
     */
    static func stopCommand(identifier: String, forced: Bool = false) { // TODO: pause and replay downloads using task.suspend() and task.resume()
        if let task = runningCommands[identifier] {
            if forced {
                task.interrupt() // SIGTERM
            } else {
                task.terminate() // SIGKILL
            }
            runningCommands.removeValue(forKey: identifier)
        } else {
            log.error("Unable to stop Legendary command: Bad identifier.")
        }
    }
    
    /// Stops the execution of all commands.
    static func stopAllCommands(forced: Bool) {
        runningCommands.keys.forEach {
            stopCommand(identifier: $0, forced: forced)
        }
    }
    
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
        platform: Mythic.Game.Platform,
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
        guard args.game.source == .epic else { throw IsNotLegendaryError() }
        // guard args.type != .uninstall else { do {/* Add uninstallation support via dialog */}; return }
        
        // TODO: data lock handling
        
        let operation: GameOperation = .shared
        
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
        
        // swiftlint:disable force_try
        let progressRegex: Regex = try! .init(#"Progress: (?<percentage>\d+\.\d+)% \((?<downloadedObjects>\d+)/(?<totalObjects>\d+)\), Running for (?<runtime>\d+:\d+:\d+), ETA: (?<eta>\d+:\d+:\d+)"#)
        let downloadRegex: Regex = try! .init(#"Downloaded: (?<downloaded>\d+\.\d+) \w+, Written: (?<written>\d+\.\d+) \w+"#)
        let cacheRegex: Regex = try! .init(#"Cache usage: (?<usage>\d+\.\d+) \w+, active tasks: (?<activeTasks>\d+)"#)
        let downloadSpeedRegex: Regex = try! .init(#"\+ Download\s+- (?<raw>[\d.]+) \w+/\w+ \(raw\) / (?<decompressed>[\d.]+) \w+/\w+ \(decompressed\)"#)
        let diskSpeedRegex: Regex = try! .init(#"\+ Disk\s+- (?<write>[\d.]+) \w+/\w+ \(write\) / (?<read>[\d.]+) \w+/\w+ \(read\)"#)
        // swiftlint:enable force_try
        
        var error: Error?
        
        try await command(arguments: argBuilder, identifier: "install") { output in
            guard !output.stdout.contains("All done! Download manager quitting...") else {
                operation.current = nil; return
            }
            
            if let match = try? Regex(#"Failure: (.*)"#).firstMatch(in: output.stdout) {
                stopCommand(identifier: "install")
                error = InstallationError(errorDescription: .init(match.last?.substring ?? "Unknown Error"))
                return
            }
            
            if let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: output.stderr) {
                stopCommand(identifier: "install")
                error = InstallationError(errorDescription: .init(match.last?.substring ?? "Unknown Error"))
                return
            }
            
            if let match = try? progressRegex.firstMatch(in: output.stderr) {
                DispatchQueue.main.async {
                    operation.status.progress = GameOperation.InstallStatus.Progress(
                        percentage: Double(match["percentage"]?.substring ?? "") ?? 0.0,
                        downloadedObjects: Int(match["downloadedObjects"]?.substring ?? "") ?? 0,
                        totalObjects: Int(match["totalObjects"]?.substring ?? "") ?? 0,
                        runtime: String(match["runtime"]?.substring ?? "00:00:00"),
                        eta: String(match["eta"]?.substring ?? "00:00:00")
                    )
                }
            }
            if let match = try? downloadRegex.firstMatch(in: output.stderr) {
                DispatchQueue.main.async {
                    operation.status.download = GameOperation.InstallStatus.Download(
                        downloaded: Double(match["downloaded"]?.substring ?? "") ?? 0.0,
                        written: Double(match["written"]?.substring ?? "") ?? 0.0
                    )
                }
            }
            if let match = try? cacheRegex.firstMatch(in: output.stderr) {
                DispatchQueue.main.async {
                    operation.status.cache = GameOperation.InstallStatus.Cache(
                        usage: Double(match["usage"]?.substring ?? "") ?? 0.0,
                        activeTasks: Int(match["activeTasks"]?.substring ?? "") ?? 0
                    )
                }
            }
            if let match = try? downloadSpeedRegex.firstMatch(in: output.stderr) {
                DispatchQueue.main.async {
                    operation.status.downloadSpeed = GameOperation.InstallStatus.DownloadSpeed(
                        raw: Double(match["raw"]?.substring ?? "") ?? 0.0,
                        decompressed: Double(match["decompressed"]?.substring ?? "") ?? 0.0
                    )
                }
            }
            if let match = try? diskSpeedRegex.firstMatch(in: output.stderr) {
                DispatchQueue.main.async {
                    operation.status.diskSpeed = GameOperation.InstallStatus.DiskSpeed(
                        write: Double(match["write"]?.substring ?? "") ?? 0.0,
                        read: Double(match["read"]?.substring ?? "") ?? 0.0
                    )
                }
            }
        }
        
        if error != nil { throw error! }
    }
    
    static func move(game: Mythic.Game, newPath: String) async throws {
        if let oldPath = try getGamePath(game: game) {
            guard files.isWritableFile(atPath: oldPath) else { throw FileLocations.FileNotModifiableError(.init(filePath: oldPath)) }
            try files.moveItem(atPath: oldPath, toPath: "\(newPath)/\(oldPath.components(separatedBy: "/").last!)")
            
            try await command(
                arguments: ["move", game.id, newPath, "--skip-move"],
                identifier: "move"
            ) { _ in }
            
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
    
    static func signIn(authKey: String) async throws -> Bool {
        var isLoggedIn = false
        
        try await command(arguments: ["auth", "--code", authKey], identifier: "signin", waits: true ) { output in
            isLoggedIn = (isLoggedIn == true ? true : output.stderr.contains("Successfully logged in as"))
        }
        
        return isLoggedIn
    }

    /**
     Launches games.
     
     - Parameters:
     - game: The game to launch.
     */
    static func launch(game: Mythic.Game) async throws {
        guard try Legendary.getInstalledGames().contains(game) else {
            log.error("Unable to launch game, not installed or missing")
            throw GameDoesNotExistError(game)
        }
        
        guard game.platform == .windows && Engine.exists else { throw Engine.NotInstalledError() }
        guard let bottleURL = game.bottleURL else { throw Wine.BottleDoesNotExistError() } // FIXME: Bottle Revamp
        let bottle = try Wine.getBottleObject(url: bottleURL)
        
        DispatchQueue.main.async {
            GameOperation.shared.launching = game
        }
        
        try defaults.encodeAndSet(game, forKey: "recentlyPlayed")
        
        var arguments = [
            "launch",
            game.id,
            needsUpdate(game: game) ? "--skip-version-check" : nil
        ] .compactMap { $0 }
        
        var environmentVariables = ["MTL_HUD_ENABLED": bottle.settings.metalHUD ? "1" : "0"]
        
        if game.platform == .windows {
            arguments += ["--wine", Engine.directory.appending(path: "wine/bin/wine64").path]
            environmentVariables["WINEPREFIX"] = bottle.url.path(percentEncoded: false)
            environmentVariables["WINEMSYNC"] = bottle.settings.msync ? "1" : "0"
        }
        
        arguments.append(contentsOf: game.launchArguments)
        
        try await command(arguments: arguments, identifier: "launch_\(game.id)", environment: environmentVariables) { _  in }
        
        DispatchQueue.main.async {
            GameOperation.shared.launching = nil
        }
    }
    
    // MARK: Get Game Platform Method
    /**
     Determines the platform of the game.
     
     - Parameter platform: The platform of the game.
     - Throws: `UnableToGetPlatformError` if the platform is not "Mac" or "Windows".
     - Returns: The platform of the game as a `Platform` enum.
     */
    static func getGamePlatform(game: Mythic.Game) throws -> Mythic.Game.Platform {
        guard game.source == .epic else { throw IsNotLegendaryError() }
        
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
                apps.append(Mythic.Game(source: .epic, title: title, id: id))
            }
        }
        
        return apps
    }
    
    static func getGamePath(game: Mythic.Game) throws -> String? { // no need to throw if it returns nil
        guard signedIn() else { throw NotSignedInError() }
        guard game.source == .epic else { throw IsNotLegendaryError() }
        
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
        
        let games = try files.contentsOfDirectory(atPath: metadata).map { file -> Mythic.Game in
            let json = try JSON(data: .init(contentsOf: .init(filePath: "\(metadata)/\(file)")))
            return .init(source: .epic, title: json["app_title"].stringValue, id: json["app_name"].stringValue)
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
        guard game.source == .epic else { throw IsNotLegendaryError() }
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
     
     - Returns: The URL of the retrieved image.
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
}
