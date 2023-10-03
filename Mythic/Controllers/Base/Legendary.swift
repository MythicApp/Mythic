//
//  Legendary.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 21/9/2023.
//


import Foundation
import OSLog

import SwiftyJSON

///  Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities. see: https://github.com/derrod/legendary
struct Legendary {
    
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "legendary"
    )
    
    /// Stores legendary command outputs locally, in order to deliver content faster
    private static var commandCache: [String: (stdout: Data, stderr: Data)] = [:]

    /// Run a legendary command, using the included legendary binary.
    static func command(args: [String], useCache: Bool, input: String? = nil) -> (stdout: Data, stderr: Data) {
        
        /// Conntains instances of the async DispatchQueues
        struct QueueContainer {
            let cache: DispatchQueue = DispatchQueue(label: "commandCacheQueue")
            let command: DispatchQueue = DispatchQueue(label: "commandQueue", attributes: .concurrent)
        }
        
        let queue = QueueContainer()
        
        let commandKey = String(describing: args)
        
        if useCache,
           let cachedOutput = queue.cache.sync(execute: { commandCache[commandKey] }),
           !cachedOutput.stdout.isEmpty && !cachedOutput.stderr.isEmpty {
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
            task.executableURL = URL(fileURLWithPath: Bundle.main.path(forResource: "legendary/legendary", ofType: nil)!)
            
            /// Contains instances of Pipe, for stderr and stdout
            struct PipeContainer {
                let stdout: Pipe = Pipe()
                let stderr: Pipe = Pipe()
            }
            
            /// Contains instances of Data, for handling pipes
            struct DataContainer {
                var stdout = Data()
                var stderr = Data()
            }
            
            let pipe = PipeContainer()
            var data = DataContainer()
            let asyncGroup = DispatchGroup()
            
            task.standardError = pipe.stderr
            task.standardOutput = pipe.stdout
            task.standardInput = input
            
            task.currentDirectoryURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            task.arguments = args
            task.environment = ["XDG_CONFIG_HOME": Bundle.appHome]
            log.debug("Legendary configuration environment: \(task.environment?["XDG_CONFIG_HOME"] ?? "nil")")
            
            let fullCommand = "\(task.executableURL?.path ?? "") \(task.arguments?.joined(separator: " ") ?? "")"
            
            log.debug("executing \(fullCommand)")
            
            // Asynchronous output
            queue.command.async(group: asyncGroup) {
                while true {
                    let availableData = pipe.stdout.fileHandleForReading.availableData
                    if availableData.isEmpty {
                        break
                    }
                    data.stdout.append(availableData)
                }
            }
            
            queue.command.async(group: asyncGroup) {
                while true {
                    let availableData = pipe.stderr.fileHandleForReading.availableData
                    if availableData.isEmpty {
                        break
                    }
                    data.stderr.append(availableData)
                }
            }
            
            try! task.run()
            
            task.waitUntilExit()
            asyncGroup.wait()
            
            let output: (stdout: Data, stderr: Data) = (
                data.stdout, data.stderr
            )
            
            if let stderrString = String(data: output.stderr, encoding: .utf8) {
                if !stderrString.isEmpty {
                    // https://docs.python.org/3/library/logging.html#logging-levels
                    if stderrString.contains("DEBUG:") {
                        log.debug("\(stderrString)")
                    } else if stderrString.contains("INFO:") {
                        log.info("\(stderrString)")
                    } else if stderrString.contains("WARNING:") { // Legendary just likes being different
                        log.warning("\(stderrString)")
                    } else if stderrString.contains("ERROR:") {
                        log.error("\(stderrString)")
                    } else if stderrString.contains("CRITICAL:") {
                        log.critical("\(stderrString)")
                    } else {
                        log.log("\(stderrString)")
                    }
                }
            } else {
                log.warning("empty stderr\ncommand key: \(commandKey)")
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
    
    /// Wipe legendary's commands cache. This will slow most legendary commands until cache is rebuilt.
    static func clearCommandCache() {
        commandCache = [:]
        log.notice("Cleared legendary command cache successfully.")
    }
    
    /// Queries the user that is currently signed in.
    static func whoAmI(useCache: Bool?) -> String {
        var accountString: String = ""
        if let account = try? JSON(data: Legendary.command(args: ["status","--json"], useCache: useCache ?? false).stdout)["account"] {
            accountString = String(describing: account)
        }
        
        /*
         annoying
         
        do {
            if let data = try JSONSerialization.jsonObject(
                with: Legendary.command(
                    args: ["status","--json"],
                    useCache: useCache ?? false
                ).stdout,
                options: []
            ) as? [String: Any] {
                if let account = data["account"] as? String {
                    accountString = account
                }
            }
        } catch {
            
        }
         */
         
        
        return accountString
    }
    
    /// Boolean verifier for the user's epic games signin state.
    static func signedIn(useCache: Bool? = false, whoAmIOutput: String? = nil) -> Bool {
        if let output = whoAmIOutput {
            return output != "<not logged in>"
        } else {
            return Legendary.whoAmI(useCache: useCache) != "<not logged in>"
        }
    }
}
