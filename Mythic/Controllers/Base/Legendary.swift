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
    
    /// Logger instance for logging
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "legendary"
    )
    
    /// Cache for storing command outputs
    private static var commandCache: [String: (stdout: Data, stderr: Data)] = [:]
    
    /// Run a legendary command, using the included legendary binary.
    ///
    /// - Parameters:
    ///   - args: The command arguments.
    ///   - useCache: Flag indicating whether to use cached output.
    ///   - input: Optional input string for the command.
    ///   - inputIf: Optional condition to be checked for in the output streams before input is appended.
    ///   - halt: Optional semaphore to halt script execution.
    ///   - handlers: Optional closure that gets output appended to it immediately.
    /// - Returns: A tuple containing stdout and stderr data.
    static func command(
        args: [String],
        useCache: Bool,
        input: String? = nil,
        inputIf: InputIfCondition? = nil,
        halt: DispatchSemaphore? = nil,
        handlers: OutputHandler? = nil
    ) -> (stdout: Data, stderr: Data) {
        
        /// Contains instances of the async DispatchQueues
        struct QueueContainer {
            let cache: DispatchQueue = DispatchQueue(label: "commandCacheQueue")
            let command: DispatchQueue = DispatchQueue(label: "commandQueue", attributes: .concurrent)
        }
        
        let queue = QueueContainer()
        
        let commandKey = String(describing: args)
        
        if useCache, let cachedOutput = queue.cache.sync(execute: { commandCache[commandKey] }), !cachedOutput.stdout.isEmpty && !cachedOutput.stderr.isEmpty {
            log.debug("Cached, returning.")
            DispatchQueue.global(qos: .userInitiated).async {
                _ = run()
                log.debug("New cache appended.")
            }
            return cachedOutput
        } else {
            log.debug("\(useCache ? "Cache not found, creating" : "Cache disabled for this task.")")
            return run()
        }
        
        func run() -> (stdout: Data, stderr: Data) {
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
            let asyncGroup = DispatchGroup()
            
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
            queue.command.async(group: asyncGroup) {
                while true {
                    let availableData = pipe.stdout.fileHandleForReading.availableData
                    if availableData.isEmpty { break }
                    data.stdout.append(availableData)
                    
                    if let inputIf = inputIf, inputIf.stream == .stdout {
                        if let availableData = String(data: availableData, encoding: .utf8), availableData.contains(inputIf.string) {
                            if let inputData = input?.data(using: .utf8) {
                                pipe.stdin.fileHandleForWriting.write(inputData)
                                pipe.stdin.fileHandleForWriting.closeFile()
                            }
                        }
                    }
                    
                    if let handlers = handlers, let outputString = String(data: availableData, encoding: .utf8) {
                        handlers.stdout(outputString)
                    }
                    
                    if let halt = halt, halt.wait(timeout: .now()) == .success {
                        log.debug("stdout output async stopped due to halt sephamore being signalled.")
                        return
                    }
                }
            }
            
            // async stderr appending
            queue.command.async(group: asyncGroup) {
                while true {
                    let availableData = pipe.stderr.fileHandleForReading.availableData
                    if availableData.isEmpty { break }
                    data.stderr.append(availableData)
                    
                    if let inputIf = inputIf, inputIf.stream == .stderr {
                        if let availableData = String(data: availableData, encoding: .utf8), availableData.contains(inputIf.string) {
                            if let inputData = input?.data(using: .utf8) {
                                pipe.stdin.fileHandleForWriting.write(inputData)
                                pipe.stdin.fileHandleForWriting.closeFile()
                            }
                        }
                    }
                    
                    if let handlers = handlers, let outputString = String(data: availableData, encoding: .utf8) {
                        handlers.stderr(outputString)
                    }
                    
                    if let halt = halt, halt.wait(timeout: .now()) == .success {
                        log.debug("stderr output async stopped due to halt sephamore being signalled.")
                        return
                    }
                }
            }
            
            if let input = input, !input.isEmpty && inputIf == nil {
                if let inputData = input.data(using: .utf8) {
                    pipe.stdin.fileHandleForWriting.write(inputData)
                    pipe.stdin.fileHandleForWriting.closeFile()
                }
            }
            
            if let halt = halt, halt.wait(timeout: .now()) == .success {
                log.debug("Halt signal fired.")
                return (Data(), Data())
            }
            
            // run
            
            do {
                try task.run()
                
                task.waitUntilExit()
                asyncGroup.wait()
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
    static func installGame(game: String, optionalPacks: [String]? = nil, cancelSemaphore: DispatchSemaphore? = nil) {
        guard getInstallable().appNames.contains(game) else {
            log.error("Game app name doesn't exist: \(game)")
            return
        }
        
        dataLockInUse = (true, .installing)
        Installing.value = true
        Installing.game = game
        
        // thank you gpt 🙏🏾🙏🏾 i am not regexing allat
        let handlers = OutputHandler(
            stdout: { _ in },
            stderr: { stderr in
                struct Regex {
                    static let progress = try! NSRegularExpression(pattern: #"Progress: (\d+\.\d+)% \((\d+)/(\d+)\), Running for (\d+:\d+:\d+), ETA: (\d+:\d+:\d+)"#)
                    static let download = try! NSRegularExpression(pattern: #"Downloaded: ([\d.]+) \w+, Written: ([\d.]+) \w+"#)
                    static let cache = try! NSRegularExpression(pattern: #"Cache usage: ([\d.]+) \w+, active tasks: (\d+)"#)
                    static let downloadAdvanced = try! NSRegularExpression(pattern: #"\+ Download\s+- ([\d.]+) \w+/\w+ \(raw\) / ([\d.]+) \w+/\w+ \(decompressed\)"#)
                    static let disk = try! NSRegularExpression(pattern: #"\+ Disk\s+- ([\d.]+) \w+/\w+ \(write\) / ([\d.]+) \w+/\w+ \(read\)"#)
                }
                
                var status = Installing.shared._status
                
                var lastPercentage: Double = 0.0
                stderr.enumerateLines { line, _ in
                    if line.contains("[DLManager] INFO:") {
                        if !line.contains("Finished installation process in") {
                            let range = NSRange(line.startIndex..<line.endIndex, in: line)
                            
                            if let match = Regex.progress.firstMatch(in: line, options: [], range: range) {
                                let percentage = Double(line[Range(match.range(at: 1), in: line)!]) ?? 0
                                status.progress = (
                                    percentage: max(percentage, lastPercentage) /* percentage > lastPercentage ? percentage : lastPercentage */,
                                    downloaded: Int(line[Range(match.range(at: 2), in: line)!]) ?? 0,
                                    total: Int(line[Range(match.range(at: 3), in: line)!]) ?? 0,
                                    runtime: line[Range(match.range(at: 4), in: line)!],
                                    eta: line[Range(match.range(at: 5), in: line)!]
                                )
                                
                                lastPercentage = percentage
                            } else if let match = Regex.download.firstMatch(in: line, options: [], range: range) {
                                status.download = ( // MiB | 1 MB = (10^6/2^20) MiB
                                    downloaded: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    written: Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if let match = Regex.cache.firstMatch(in: line, options: [], range: range) {
                                status.cache = (
                                    usage: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0, // MiB
                                    activeTasks: Int(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if let match = Regex.downloadAdvanced.firstMatch(in: line, options: [], range: range) {
                                status.downloadAdvanced = ( // MiB/s
                                    raw: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    decompressed: Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            } else if let match = Regex.disk.firstMatch(in: line, options: [], range: range) {
                                status.disk = ( // MiB/s
                                    write: Double(line[Range(match.range(at: 1), in: line)!]) ?? 0,
                                    read: Double(line[Range(match.range(at: 2), in: line)!]) ?? 0
                                )
                            }
                        } else {
                            Installing.shared.reset()
                        }
                    }
                    DispatchQueue.main.async {
                        Installing.shared._status = status
                        dump(Installing.shared._status)
                    }
                }
            }
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            _ = command(
                args: ["--yes", "install", game],
                useCache: false,
                input: "\(Array(optionalPacks ?? Array()).joined(separator: ", "))\n",
                inputIf: .init(stream: .stderr, string: "Additional packs [Enter to confirm]:"),
                halt: cancelSemaphore,
                handlers: handlers
            )
        }
    }
    
    /// Wipe legendary's commands cache. This will slow most legendary commands until cache is rebuilt.
    static func clearCommandCache() {
        commandCache = [:]
        log.notice("Cleared legendary command cache successfully.")
    }
    
    /// Queries the user that is currently signed into epic games.
    /// This command has no delay.
    ///
    /// - Returns: The user's account information as a string.
    static func whoAmI() -> String {
        let config = "\(Bundle.appHome)/legendary"
        let user = "\(config)/user.json"
        var whoIAm: String = ""
        if FileManager.default.fileExists(atPath: config) {
            if FileManager.default.fileExists(atPath: user) {
                if let displayName = try? JSON(data: Data(contentsOf: URL(fileURLWithPath: user)))["displayName"] {
                    whoIAm = String(describing: displayName)
                }
            } else {
                whoIAm = "Nobody"
            }
        }
        
        return whoIAm
    }
    
    /// Boolean verifier for the user's epic games signin state.
    /// This command has no delay.
    ///
    /// - Returns: `true` if the user is signed in, otherwise `false`.
    static func signedIn() -> Bool { return whoAmI() != "Nobody" }
    
    /// Retrieve installed games from epic games services.
    ///
    /// - Returns: A tuple containing arrays of app names and app titles.
    static func getInstalledGames() -> (appNames: [String], appTitles: [String]) {
        guard signedIn() else { return ([], []) }
        let json = try? JSON(data: command(args: ["list-installed","--json"], useCache: true).stdout)
        return extractAppNamesAndTitles(from: json)
    }
    
    /// Retrieve installed games from epic games services.
    ///
    /// - Returns: A tuple containing arrays of app names and app titles.
    static func getInstallable() -> (appNames: [String], appTitles: [String]) {
        guard signedIn() else { return ([], []) }
        let json = try? JSON(data: command(args: ["list","--platform","Windows","--third-party","--json"], useCache: true).stdout)
        return extractAppNamesAndTitles(from: json)
    }
    
    /// Get game images with "DieselGameBox" metadata.
    ///
    /// - Parameter imageType: The type of images to retrieve (normal or tall).
    /// - Returns: A dictionary with app names as keys and image URLs as values.
    static func getImages(imageType: ImageType) -> [String: String] {
        guard signedIn() else { return [:] }
        let json = try? JSON(data: command(args: ["list","--platform","Windows","--third-party","--json"], useCache: true).stdout)
        
        var urls: [String: String] = [:]
        
        for game in json! {
            let appName = String(describing: game.1["app_name"])
            if let keyImages = game.1["metadata"]["keyImages"].array {
                var image: [JSON] = []
                
                switch imageType {
                case .normal:
                    image = keyImages.filter { $0["type"].string == "DieselGameBox" }
                case .tall:
                    image = keyImages.filter { $0["type"].string == "DieselGameBoxTall" }
                }
                
                if let imageUrl = image.first?["url"].string {
                    urls[appName] = imageUrl
                }
            }
        }
        
        return urls
    }
    
    // Later implement: aliases.json checker, isAlias(game: String), returns string with alias of game
    
    /// Retrieve the game's app\_name from the game's title.
    ///
    /// - Parameter appTitle: The title of the game.
    /// - Returns: The app name of the game.
    static func getAppNameFromTitle(appTitle: String) -> String {
        guard signedIn() else { return "" }
        let json = try? JSON(data: command(args: ["info", appTitle, "--json"], useCache: true).stdout)
        return json!["game"]["app_name"].stringValue
    }
    
    /// Retrieve the game's title from the game's app\_name.
    ///
    /// - Parameter appName: The app name of the game.
    /// - Returns: The title of the game.
    static func getTitleFromAppName(appName: String) -> String {
        guard signedIn() else { return "" }
        let json = try? JSON(data: command(args: ["info", appName, "--json"], useCache: true).stdout)
        return json!["game"]["title"].stringValue
    }
    
    /* // // // // // // // // // // // // // // // //
     ___   _   _  _  ___ ___ ___   _______  _  _ ___
     |   \ /_\ | \| |/ __| __| _ \ |_  / _ \| \| | __|
     | |) / _ \| .` | (_ | _||   /  / / (_) | .` | _|
     |___/_/ \_\_|\_|\___|___|_|_\ /___\___/|_|\_|___|
     
     */ // // // // // // // // // // // // // // // /
    
    /// Well, what do you think it does?
    private static func extractAppNamesAndTitles(from json: JSON?) -> (appNames: [String], appTitles: [String]) {
        var appNames: [String] = []
        var appTitles: [String] = []
        if json?.exists() == true {
            for game in json! {
                appNames.append(String(describing: game.1["app_name"]))
                appTitles.append(String(describing: game.1["app_title"]))
            }
        }
        return (appNames, appTitles)
    }
}
