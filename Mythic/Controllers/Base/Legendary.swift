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
    private static var commandCache: [String: (stdout: (data: Data, string: String), stderr: (data: Data, string: String))] = [:]

    /// Run a legendary command, using the included legendary binary.
    static func command(args: [String], useCache: Bool = true, input: String? = nil) -> (stdout: (data: Data, string: String), stderr: (data: Data, string: String)) {
        
        /// Conntains instances of the async DispatchQueues
        struct QueueContainer {
            let cache: DispatchQueue = DispatchQueue(label: "commandCacheQueue")
            let command: DispatchQueue = DispatchQueue(label: "commandQueue", attributes: .concurrent)
        }
        
        let queue = QueueContainer()
        
        let commandKey = String(describing: args)
        
        if useCache == true, let cachedOutput = queue.cache.sync(execute: { commandCache[commandKey] }) {
            log.debug("Cached, returning.")
            DispatchQueue.global().async {
                _ = run()
                log.debug("New cache appended.")
            }
            return cachedOutput
        } else {
            if useCache == false {
                log.debug("Cache not enabled for this task.")
            } else {
                log.debug("Cache not found, creating.")
            }
            return run()
        }
        
        func run() -> (stdout: (data: Data, string: String), stderr: (data: Data, string: String)) {
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
            
            let output: (stdout: (data: Data, string: String), stderr: (data: Data, string: String)) = (
                (
                    data.stdout,
                    String(data: data.stdout, encoding: .utf8) ?? ""
                ),
                (
                    data.stderr,
                    String(data: data.stderr, encoding: .utf8) ?? ""
                )
            )
            
            if !output.stderr.string.isEmpty {
                // https://docs.python.org/3/library/logging.html#logging-levels
                if output.stderr.string.contains("DEBUG:") {
                    log.debug("\(output.stderr.string)")
                } else if output.stderr.string.contains("INFO:") {
                    log.info("\(output.stderr.string)")
                } else if output.stderr.string.contains("WARN:") {
                    log.warning("\(output.stderr.string)")
                } else if output.stderr.string.contains("ERROR:") {
                    log.error("\(output.stderr.string)")
                } else if output.stderr.string.contains("CRITICAL:") {
                    log.critical("\(output.stderr.string)")
                } else {
                    log.log("\(output.stderr.string)")
                }
            } else {
                log.warning("empty stderr\ncommand key: \(commandKey)")
            }
            
            if !output.stdout.string.isEmpty {
                log.debug("\(output.stdout.string)")
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
        if let account = try? JSON(data: Legendary.command(args: ["status","--json"], useCache: useCache ?? false).stdout.data)["account"] {
            accountString = String(describing: account)
        }
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
