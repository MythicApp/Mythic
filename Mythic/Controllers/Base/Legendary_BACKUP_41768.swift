//
//  Legendary.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 21/9/2023.
//

import Foundation
import SwiftyJSON
import OSLog

/// Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities. See: https://github.com/derrod/legendary
class Legendary {
    
    /// The file location for legendary's configuration files.
    static let configLocation = "\(Bundle.appHome)/legendary"
    
    /// Logger instance for logging
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "legendary"
    )
    
    /// Cache for storing command outputs
    private static var commandCache: [String: (stdout: Data, stderr: Data)] = Dictionary()
    
    /// Run a legendary command, using the included legendary binary.
    ///
    /// - Parameters:
    ///   - args: The command arguments.
    ///   - useCache: Flag indicating whether to use cached output.
    ///   - input: Optional input string for the command.
    ///   - inputIf: Optional condition to be checked for in the output streams before input is appended.
    ///   ~~- halt: Optional semaphore to halt script execution.~~
    ///   - asyncOutput: Optional closure that gets output appended to it immediately.
    /// - Returns: A tuple containing stdout and stderr data.
    static func command(
        args: [String],
        useCache: Bool,
        input: String? = nil,
        inputIf: InputIfCondition? = nil,
        asyncOutput: OutputHandler? = nil
    ) async -> (stdout: Data, stderr: Data) {
        
        /// Contains instances of the async DispatchQueues
        struct QueueContainer {
            let cache: DispatchQueue = DispatchQueue(label: "commandCacheQueue")
            let command: DispatchQueue = DispatchQueue(label: "commandQueue", attributes: .concurrent)
        }
        
        let queue = QueueContainer()
        
        let commandKey = String(describing: args)
        
        if useCache, let cachedOutput = queue.cache.sync(execute: { commandCache[commandKey] }), !cachedOutput.stdout.isEmpty && !cachedOutput.stderr.isEmpty {
            log.debug("Cached, returning.")
            Task {
                _ = await run()
                log.debug("Cache returned, and new cache successfully appended.")
            }
            return cachedOutput
        } else {
            log.debug("\(useCache ? "Cache not found, creating" : "Cache disabled for this task.")")
            return await run()
        }
        
        @Sendable
        func run() async -> (stdout: Data, stderr: Data) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: Bundle.main.path(forResource: "legendary/cli", ofType: nil)!)
            
            /// Contains instances of Pipe, for stderr and stdout.
            struct PipeContainer {
                let stdout = Pipe()
                let stderr = Pipe()
                let stdin = Pipe()
            }
            
            /// Contains instances of Data, for handling pipes
            struct DataContainer {
                var stdout = Data()
                var stderr = Data()
            }
            
            let pipe = PipeContainer()
            var data = DataContainer()
            
            // initialise legendary cli and config env
            
            task.standardError = pipe.stderr
            task.standardOutput = pipe.stdout
            task.standardInput = input?.isEmpty != true ? nil : pipe.stdin
            
            task.currentDirectoryURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            task.arguments = args
            task.environment = ["XDG_CONFIG_HOME": Bundle.appHome]
            log.debug("Legendary configuration environment: \(task.environment?["XDG_CONFIG_HOME"] ?? "nil")")
            
            let fullCommand = "\(task.executableURL?.path ?? "") \(task.arguments?.joined(separator: " ") ?? "")"
            
            log.debug("executing \(fullCommand)")
            
            // async stdout appending
            queue.command.async(qos: .utility) {
                while true {
                    let availableData = pipe.stdout.fileHandleForReading.availableData
                    if availableData.isEmpty { break }
                    
                    data.stdout.append(availableData) // no idea how to fix
                    
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
            
            // async stderr appending
            queue.command.async(qos: .utility) {
                while true {
                    let availableData = pipe.stderr.fileHandleForReading.availableData
                    if availableData.isEmpty { break }
                    
                    data.stderr.append(availableData) // no idea how to fix
                    
                    if let inputIf = inputIf, inputIf.stream == .stderr {
                        if let availableData = String(data: availableData, encoding: .utf8), availableData.contains(inputIf.string) {
                            if let inputData = input?.data(using: .utf8) {
                                pipe.stdin.fileHandleForWriting.write(inputData)
                                pipe.stdin.fileHandleForWriting.closeFile()
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
            
            // run
            
            do {
                try task.run()
                
                task.waitUntilExit()
                // asyncGroup.wait()
            } catch {
                log.fault("Legendary fault: \(error.localizedDescription)")
                return (Data(), Data())
            }
            
            // output (stderr/out) handler
            
            let output: (stdout: Data, stderr: Data) = (
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
                log.warning("empty stderr:\ncommand key: \(commandKey)")
            }
            
            if let stdoutString = String(data: output.stdout, encoding: .utf8) {
                if !stdoutString.isEmpty {
                    log.debug("\(stdoutString)")
                }
            } else {
                log.warning("empty stderr\ncommand key: \(commandKey)")
            }
            
            queue.cache.sync { commandCache[commandKey] = output } // store output in cache
            
            return output
        }
    }
    
    /// Installs games using legendary, what else?
    ///
    /// - Parameters:
    ///   - game: The game's app\_name
    ///   - optionalPacks: Optional packs to install along with the base game
    /// - Throws: A NotSignedInError.
    static func installGame(
        game: Game,
        optionalPacks: [String]? = nil,
        basePath: String? = nil,
        gameFolder: String? = nil,
        platform: GamePlatform? = nil
    ) async {
        // basePath, gameFolder, platform not implemented
        
        dataLockInUse = (true, .installing)
        Installing.value = true
        Installing.game = game
        
        // thank you gpt 🙏🏾🙏🏾 i am not regexing allat
        struct Regex {
            static let progress = try? NSRegularExpression(pattern: #"Progress: (\d+\.\d+)% \((\d+)/(\d+)\), Running for (\d+:\d+:\d+), ETA: (\d+:\d+:\d+)"#)
            static let download = try? NSRegularExpression(pattern: #"Downloaded: ([\d.]+) \w+, Written: ([\d.]+) \w+"#)
            static let cache = try? NSRegularExpression(pattern: #"Cache usage: ([\d.]+) \w+, active tasks: (\d+)"#)
            static let downloadAdvanced = try? NSRegularExpression(pattern: #"\+ Download\s+- ([\d.]+) \w+/\w+ \(raw\) / ([\d.]+) \w+/\w+ \(decompressed\)"#)
            static let disk = try? NSRegularExpression(pattern: #"\+ Disk\s+- ([\d.]+) \w+/\w+ \(write\) / ([\d.]+) \w+/\w+ \(read\)"#)
        }
        
        var status = Installing.shared._status
        
        let asyncOutput = OutputHandler(
            stdout: { _ in },
            stderr: { output in
                output.enumerateLines { line, _ in
                    if line.contains("[DLManager] INFO:") {
                        if !line.contains("Finished installation process in") {
                            
                            let range = NSRange(line.startIndex..<line.endIndex, in: line)
                            
                            if let match = Regex.progress?.firstMatch(in: line, options: [], range: range) {
                                status.progress = (
                                    percentage: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    downloaded: Int(line[Range(match.range(at: 2), in: line)!]) ?? 0,
                                    total: Int(line[Range(match.range(at: 3), in: line)!]) ?? 0,
                                    runtime: line[Range(match.range(at: 4), in: line)!],
                                    eta: line[Range(match.range(at: 5), in: line)!]
                                )
                            } else if let match = Regex.download?.firstMatch(in: line, options: [], range: range) {
                                status.download = ( // MiB | 1 MB = (10^6/2^20) MiB
                                    downloaded: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    written: Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if let match = Regex.cache?.firstMatch(in: line, options: [], range: range) {
                                status.cache = (
                                    usage: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0, // MiB
                                    activeTasks: Int(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if let match = Regex.downloadAdvanced?.firstMatch(in: line, options: [], range: range) {
                                status.downloadAdvanced = ( // MiB/s
                                    raw: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    decompressed: Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if let match = Regex.disk?.firstMatch(in: line, options: [], range: range) {
                                status.disk = ( // MiB/s
                                    write: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    read: Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if line.contains("All done! Download manager quitting...") {
                                DispatchQueue.main.async {
                                    Installing.shared._finished = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // come back to later, issue creates spamability
                                        Installing.shared._finished = false
                                    }
                                }
                            }
                        } else {
                            Installing.shared.reset()
                        }
                    }
                    DispatchQueue.main.sync { // no async!!
                        Installing.shared._status = status
                        dump(Installing.shared._status)
                    }
                }
            }
        )
        
        _ = await command(
            args: ["--yes", "install", game.appName],
            useCache: false,
            input: "\(Array(optionalPacks ?? Array()).joined(separator: ", "))\n",
            inputIf: .init(stream: .stderr, string: "Additional packs [Enter to confirm]:"),
            // halt: cancelSemaphore,
            asyncOutput: asyncOutput
        )
    }
    
    /// Wipe legendary's command cache. This will slow most legendary commands until cache is rebuilt.
    static func clearCommandCache() {
        commandCache = Dictionary()
        log.notice("Cleared legendary command cache successfully.")
    }
    
    /// Queries the user that is currently signed into epic games.
    /// This command has no delay.
    ///
    /// - Returns: The user's account information as a `String`.
    static func whoAmI() -> String {
        let userJSONFileURL = URL(fileURLWithPath: "\(configLocation)/user.json")
        
        guard 
            FileManager.default.fileExists(atPath: userJSONFileURL.path),
            let json = try? JSON(data: Data(contentsOf: userJSONFileURL))
        else { return "Nobody" }
        
        return String(describing: json["displayName"])
    }
    
    /// Boolean verifier for the user's epic games signin state.
    /// This command has no delay.
    ///
    /// - Returns: `true` if the user is signed in, otherwise `false`.
    static func signedIn() -> Bool { return whoAmI() != "Nobody" }
    
    /// Retrieve installed games from epic games services.
    ///
    /// - Returns: A dictionary containing ``Legendary.Game`` objects.
    /// - Throws: A ``NotSignedInError``.
    static func getInstalledGames() throws -> [Game] {
        guard signedIn() else { throw NotSignedInError() }
        
        let installedJSONFileURL: URL = URL(fileURLWithPath: "\(configLocation)/installed.json")
        
        guard let installedData = try? Data(contentsOf: installedJSONFileURL) else {
            throw DoesNotExistError.file(file: installedJSONFileURL)
        }
        
        guard let installedGames = try JSONSerialization.jsonObject(with: installedData, options: []) as? [String: [String: Any]] else { // stupid json dependency is stupid
            return Array()
        }
        
        var apps: [Game] = Array()
        
        for (appName, gameInfo) in installedGames {
            if let title = gameInfo["title"] as? String {
                apps.append(Game(appName: appName, title: title))
            }
        }
        
        return apps
    }
    
    /// Retrieve installed games from epic games services.
    ///
    /// - Returns: An `Array` of ``Game`` objects,
    static func getInstallable() async throws -> [Game] { // (would use legendary/metadata, but online updating is crucial)
        guard signedIn() else { throw NotSignedInError() }
        
        guard let json = try? await JSON(data: command(args: ["list","--platform","Windows","--third-party","--json"], useCache: true).stdout) else {
            return Array()
        }
        
        return extractAppNamesAndTitles(from: json)
    }
    
    /// Retrieve game metadata as a JSON.
    ///
    /// - Parameter game: A ``Game`` object.
    /// - Throws: A ``DoesNotExistError`` if the metadata directory doesn't exist.
    /// - Returns: An optional `JSON` with either the metadata or `nil`.
    static func getGameMetadata(game: Game) async throws -> JSON? {
        let metadataDirectoryString = "\(configLocation)/metadata"
        
        guard let metadataDirectoryContents = try? FileManager.default.contentsOfDirectory(atPath: metadataDirectoryString) else {
            throw DoesNotExistError.directory(directory: metadataDirectoryString)
        }
        
        if let metadataFileName = metadataDirectoryContents.first(where: { $0.hasSuffix(".json") && String($0.dropLast(5)) == game.appName }),
           let data = try? Data(contentsOf: URL(fileURLWithPath: "\(metadataDirectoryString)/\(metadataFileName)")),
           let json = try? JSON(data: data) {
            return json
        }
        
        return nil
    }
    
    
    /// Get game images with "DieselGameBox" metadata.
    ///
    /// - Parameter imageType: The type of images to retrieve (normal or tall).
    /// - Throws: A ``NotSignedInError``.
    /// - Returns: A `Dictionary` with app names as keys and image URLs as values.
    static func getImages(imageType: ImageType) async throws -> [String: String] {
        guard signedIn() else { throw NotSignedInError() }
        
        guard let json = try? await JSON(data: command(args: ["list","--platform","Windows","--third-party","--json"], useCache: true).stdout) else {
            return Dictionary()
        }
        
        var urls: [String: String] = Dictionary()
        
        for game in json {
            let appName = String(describing: game.1["app_name"])
            if let keyImages = game.1["metadata"]["keyImages"].array {
                var image: [JSON] = []
                
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
    
    /// Checks if an alias of a game exists.
    ///
    /// - Parameter game: Any `String` that may return an aliased output
    /// - Returns: A tuple containing the outcome of the check, and which game it's an alias of (is an app\_name)
    static func isAlias(game: String) throws -> (Bool?, of: String?) {
        guard signedIn() else { throw NotSignedInError() }
<<<<<<< HEAD
        
        let aliasesJSONFileURL: URL = URL(fileURLWithPath: "\(configLocation)/aliases.json")
        
        guard let aliasesData = try? Data(contentsOf: aliasesJSONFileURL) else {
            throw DoesNotExistError.file(file: aliasesJSONFileURL)
        }
        
=======
        
        let aliasesJSONFileURL: URL = URL(fileURLWithPath: "\(configLocation)/aliases.json")
        
        guard let aliasesData = try? Data(contentsOf: aliasesJSONFileURL) else {
            throw DoesNotExistError.file(file: aliasesJSONFileURL)
        }
        
>>>>>>> main
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
    
<<<<<<< HEAD
    /*
    static func needsVerification(game: Game) {
=======
    static func needsVerification(game: Game) {
        
    }
    
    static func canLaunch(game: Game) {
>>>>>>> main
        
    }
    
    static func canLaunch(game: Game) -> Bool {
        
    }
     */
    
    /*
     !!! DEPRECATIÓN !!! (im not frenh)
    
    /// Retrieve the game's app\_name from the game's title.
    ///
    /// - Parameter appTitle: The title of the game.
    /// - Returns: The app name of the game.
    static func getAppNameFromTitle(appTitle: String) -> String {
        guard signedIn() else { return "" }
        
        var json: JSON = JSON()
        do { json = try JSON(data: command(args: ["info", appTitle, "--json"], useCache: true).stdout) }
        catch {  }
        return json["game"]["app_name"].stringValue
    }
    
    /// Retrieve the game's title from the game's app\_name.
    ///
    /// - Parameter appName: The app name of the game.
    /// - Returns: The title of the game.
    static func getTitleFromAppName(appName: String) -> String { // can use jsons inside legendary/metadata
        guard signedIn() else { return "" }
        let json = try? JSON(data: command(args: ["info", appName, "--json"], useCache: true).stdout)
        return json!["game"]["title"].stringValue
    }
     */
    
    /* // // // // // // // // // // // // // // // //
     ___   _   _  _  ___ ___ ___   _______  _  _ ___
     |   \ /_\ | \| |/ __| __| _ \ |_  / _ \| \| | __|
     | |) / _ \| .` | (_ | _||   /  / / (_) | .` | _|
     |___/_/ \_\_|\_|\___|___|_|_\ /___\___/|_|\_|___|
     
     */ // // // // // // // // // // // // // // // /
    
    /// Well, what do you think it does?
    private static func extractAppNamesAndTitles(from json: JSON?) -> [Game] {
        var games: [Game] = Array()
        
        if let json = json {
            for game in json {
                games.append(
                    Game(
                        appName: game.1["app_name"].string ?? String(),
                        title: game.1["app_title"].string ?? String()
                    )
                )
            }
        }
        
        return games
    }
}
