//
//  Wine.swift
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

class Wine {
    // MARK: - Variables
    
    /// Logger instance for swift parsing of wine.
    public static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "wineInterface")
    
    /// Dictionary to monitor running commands and their identifiers.
    private static var runningCommands: [String: Process] = Dictionary()
    
    /// The directory where all wine prefixes related to Mythic are stored.
    static let bottlesDirectory: URL = {
        let directory = Bundle.appContainer!.appending(path: "Bottles")
        if !files.fileExists(atPath: directory.path) {
            do {
                try files.createDirectory(at: directory, withIntermediateDirectories: false)
                Logger.file.info("Creating bottles directory")
            } catch {
                Logger.app.error("Error creating Bottles directory: \(error)")
            }
        }
        
        return directory
    }()
    
    // MARK: - Methods
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
    static func command(
        args: [String],
        identifier: String,
        prefix: URL,
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
                """
            )
            throw Libraries.NotInstalledError()
        }
        
        guard files.fileExists(atPath: prefix.path) else {
            log.error("Unable to execute wine command, prefix does not exist.")
            throw FileLocations.FileDoesNotExistError(prefix)
        }
        
        guard files.isWritableFile(atPath: prefix.path) else {
            log.error("Unable to execure wine command, prefix directory is not writable.")
            throw FileLocations.FileNotModifiableError(prefix)
        }
        
        let queue: DispatchQueue = DispatchQueue(label: "commandQueue", attributes: .concurrent)
        
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
        
        var defaultEnvironmentVariables: [String: String] = ["WINEPREFIX": (prefix.path.isEmpty ? String() : prefix.path)]
        if let additionalEnvironmentVariables = additionalEnvironmentVariables {
            defaultEnvironmentVariables.merge(additionalEnvironmentVariables) { (_, new) in new }
        }
        task.environment = defaultEnvironmentVariables
        
        let fullCommand = "\((defaultEnvironmentVariables.map { "\($0.key)=\"\($0.value)\"" }).joined(separator: " ")) \(task.executableURL!.relativePath.replacingOccurrences(of: " ", with: "\\ ")) \(task.arguments!.joined(separator: " "))"
        
        log.debug("executing \(fullCommand)")
        
        // MARK: Asynchronous stdout Appending
        queue.async(qos: .utility) {
            Task {
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
            Task {
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
            log.debug("\(stderrString)")
        } else {
            log.warning("stderr empty or nonexistent for command [\(commandKey)]")
        }
        
        if let stdoutString = String(data: output.stdout, encoding: .utf8) {
            if !stdoutString.isEmpty {
                log.debug("\(stdoutString)")
            }
        } else {
            log.warning("stdout empty or nonexistent for command [\(commandKey)]")
        }
        
        return output
    }
    
    // TODO: implement
    @available(*, unavailable, message: "Not implemented")
    static func launchWinetricks(prefix: URL) throws {
        guard Libraries.isInstalled() else {
            log.error("Unable to launch winetricks, Mythic Engine is not installed!")
            throw Libraries.NotInstalledError()
        }
    }
    
    // MARK: - Boot Method
    /**
     Boot a wine prefix. (This will create one if none exists in the URL provided in `prefix`)
     
     - Parameter prefix: The URL of the wine prefix to boot.
     */
    static func boot(prefix: URL) async throws {
        guard Libraries.isInstalled() else { throw Libraries.NotInstalledError() }
        
        let output = try await command(
            args: ["wineboot"],
            identifier: "wineboot",
            prefix: prefix
        )
        
        if let stderr = String(data: output.stderr, encoding: .utf8),
           !stderr.contains(try Regex(#"wine: configuration in (.*?) has been updated\."#)),
           !prefixExists(at: prefix) {
            log.error("Unable to create prefix \"\(prefix.lastPathComponent)\"")
            throw BootError()
        }
        
        log.notice("Successfully created prefix \"\(prefix.lastPathComponent)\"")
    }
    
    // MARK: - Prefix Exists Method
    /**
     Check for a wine prefix's existence at a file URL.
     
     - Parameter at: The `URL` of the prefix that needs to be checked.
     - Returns: Boolean value denoting the prefix's existence.
     */
    static func prefixExists(at: URL) -> Bool {
        // swiftlint:disable:previous identifier_name
        if let contents = try? files.contentsOfDirectory(atPath: at.path) {
            if contents.contains("drive_c") {
                return true
            }
        }
        
        return false
    }
}
