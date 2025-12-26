//
//  WineInterface.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 30/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import OSLog
import SemanticVersion

final class Wine { // TODO: https://forum.winehq.org/viewtopic.php?t=15416
    internal static let log = Logger(subsystem: Logger.subsystem, category: "wineInterface")
    internal static func formatLog(containerURL: URL, description: String, error: Error? = nil) -> String {
        return "(\(containerURL.prettyPath)) \(description)" + (error != nil ? ": \(error!.localizedDescription)" : (description.hasSuffix(".") ? "" : "."))
    }
    
    internal static func retrieveVersion() -> SemanticVersion? {
        let process: Process = .init()
        process.arguments = ["--version"]
        process.executableURL = Engine.directory.appending(path: "wine/bin/wine64")
        
        let result = try? process.runWrapped()
        
        if let standardOutput = result?.standardOutput,
           let match = try? Regex(#"wine-(\S+)"#).firstMatch(in: standardOutput),
           let extractedVersion = match.last?.substring {
            return SemanticVersion(fromRelaxedString: .init(extractedVersion))
        } else {
            return nil
        }
    }

    /// The directory where all wine prefixes/containers related to Mythic are stored.
    static var containersDirectory: URL? {
        let directory = Bundle.appContainer!.appending(path: "Containers")
        if FileManager.default.fileExists(atPath: directory.path) {
            return directory
        } else {
            do {
                Logger.file.info("Creating containers directory")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
                return directory
            } catch {
                Logger.app.error("Error creating Containers directory: \(error.localizedDescription)")
                return nil
            }
        }
    }

    static var containerURLs: Set<URL> {
        get {
            // FIXME: [URL] as opposed to Set<URL> for backward compatibility, will be migrated in the future
            return .init((try? UserDefaults.standard.decodeAndGet([URL].self, forKey: "containerURLs")) ?? [])
        }
        set {
            let filteredNewValue = newValue.filter({ containerExists(at: $0) })
            do {
                try UserDefaults.standard.encodeAndSet(Array(filteredNewValue), forKey: "containerURLs")
            } catch {
                log.error("Unable to encode and/or set/update containerURLs array to UserDefaults: \(error.localizedDescription)")
            }
        }
    }

    static func containerExists(at url: URL) -> Bool {
        return (try? FileManager.default.contentsOfDirectory(atPath: url.path).contains("drive_c")) ?? false
    }

    static func getContainerObject(at containerURL: URL) throws -> Container {
        let decoder = PropertyListDecoder()
        return try decoder.decode(Container.self, from: .init(contentsOf: containerURL.appending(path: "properties.plist")))
    }

    static var containerObjects: [Container] {
        return containerURLs.compactMap { try? getContainerObject(at: $0) }
    }

    private static func constructEnvironment(with containerURL: URL?, additionalVariables: [String: String] = .init()) -> [String: String] {
        var constructedEnvironment: [String: String] = .init()
        
        if let containerURL {
            constructedEnvironment["WINEPREFIX"] = containerURL.path
        }
        
        return constructedEnvironment.merging(additionalVariables, uniquingKeysWith: { $1 })
    }
    
    /// Modify a process' properties to call `wine`.
    /// This will modify `executableURL`, and `environment`, and will passthrough existing values.
    static func transformProcess(_ process: Process, containerURL: URL) {
        process.executableURL = Engine.directory.appending(path: "wine/bin/wine64")
        
        let capturedEnvironment = process.environment
        process.environment = constructEnvironment(with: containerURL, additionalVariables: capturedEnvironment ?? [:])
    }

    static func tasklist(for containerURL: URL) async throws -> [Container.Process] {
        var list: [Container.Process] = .init()
        
        let process: Process = .init()
        process.arguments = ["tasklist"]
        transformProcess(process, containerURL: containerURL)
        
        let commandResult = try await process.runWrapped()
        
        if let standardOutput = commandResult.standardOutput {
            let tasklistRegex: Regex<AnyRegexOutput>?
            // wine above major version 7 has a new tasklist format
            // swiftlint:disable force_try
            if self.retrieveVersion()?.major ?? 0 > 7 {
                tasklistRegex = try! Regex(#"^\s*(?<ImageName>.+?)\s+(?<PID>\d+)\s+(?<SessionName>\S+)\s+(?<SessionNum>\d+)\s+(?<MemUsage>[\d,]+ K)$"#)
            } else {
                tasklistRegex = try! Regex(#"(?P<ImageName>[^,]+?),(?P<PID>\d+)"#)
            }
            // swiftlint:enable force_try
            
            for line in standardOutput.split(whereSeparator: \.isNewline) {
                guard let match = try tasklistRegex?.wholeMatch(in: line) else { continue }
                
                guard let extractedImageName = match["ImageName"]?.substring,
                      let extractedPID = match["PID"]?.substring,
                      let castPID = Int(extractedPID) else { continue }
                
                list.append(
                    .init(imageName: String(extractedImageName),
                          pid: castPID,
                          sessionName: match["ImageName"]?.substring.flatMap(String.init),
                          sessionNumber: match["SessionNum"]?.substring.flatMap({ Int($0) }),
                          memoryUsage: match["MemUsage"]?.substring.flatMap({ Int($0) }))
                )
            }
        }
        
        return list
    }
    
    @discardableResult
    static func boot(at containerURL: URL, parameters: [BootParameter]) async throws -> Process.CommandResult {
        let process: Process = .init()
        process.arguments = ["wineboot"] + parameters.map(\.rawValue)
        transformProcess(process, containerURL: containerURL)
        return try await process.runWrapped()
    }

    /**
     Create a wine prefix (container).

     - Parameters:
     - baseURL: The URL where the container should be booted from.
     - name: The name that should be given to the container.
     - settings: Default settings the container should be booted with, if none already exist.
     - completion: A closure to call with the result (Container or Error).
     */
    @discardableResult
    static func createContainer(
        baseURL: URL? = containersDirectory,
        name: String,
        settings: Container.Settings = .init()
    ) async throws -> Container {
        guard let baseURL, FileManager.default.fileExists(atPath: baseURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard FileLocations.isWritableFolder(url: baseURL) else { throw CocoaError(.fileWriteUnknown) }
        guard Engine.isInstalled else { throw Engine.NotInstalledError() }

        let url: URL = baseURL.appending(path: name)

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        defer {
            Task { @MainActor in
                VariableManager.shared.setVariable("booting", value: false)
            }
        }

        await MainActor.run {
            VariableManager.shared.setVariable("booting", value: true)
        }

        do {
            guard !containerExists(at: url) else {
                log.notice("Container already exists at \(url.prettyPath)")
                let container = try Container(knownURL: url)

                // if container is found, insert in case it's not already present
                // welcome to alpha software
                containerURLs.insert(url)

                return container
            }

            let newContainer = Container(name: name, url: url, settings: settings)
            let result = try await boot(at: url, parameters: [.prefixInit])

            // swiftlint:disable:next force_try
            guard result.standardError?.contains(try! Regex(#"wine: configuration in (.*?) has been updated\."#)) == true else {
                throw Container.UnableToBootError()
            }

            containerURLs.insert(url)

            try await toggleRetinaMode(containerURL: url, toggle: settings.retinaMode)
            try await setWindowsVersion(containerURL: url, version: settings.windowsVersion)
            try await setDisplayScaling(containerURL: url, dpi: settings.scaling)

            log.error("\(formatLog(containerURL: url, description: "Created container"))")
            return newContainer
        } catch {
            log.error("\(formatLog(containerURL: url, description: "Unable to create container", error: error))")
            throw error
        }
    }

    /// - Returns: Relevant environment variables as configured in a container for game launch.
    static func assembleEnvironmentVariables(forContainer containerURL: URL, container: Container? = nil) throws -> [String: String] {
        guard containerExists(at: containerURL) else { throw Wine.Container.DoesNotExistError() }

        let container = try container ?? getContainerObject(at: containerURL)
        var environmentVariables: [String: String] = [:]

        environmentVariables["WINEMSYNC"] = container.settings.msync.numericalValue.description
        environmentVariables["ROSETTA_ADVERTISE_AVX"] = container.settings.avx2.numericalValue.description

        if container.settings.dxvk {
            environmentVariables["WINEDLLOVERRIDES"] = "d3d10core,d3d11=n,b"
            environmentVariables["DXVK_ASYNC"] = container.settings.dxvkAsync.numericalValue.description
        }

        if container.settings.metalHUD {
            if container.settings.dxvk {
                environmentVariables["DXVK_HUD"] = "full"
            } else {
                environmentVariables["MTL_HUD_ENABLED"] = "1"
            }
        }

        return environmentVariables
    }

    static func deleteContainer(containerURL: URL) throws {
        log.notice("Deleting container \(containerURL.lastPathComponent) (\(containerURL))")
        guard containerExists(at: containerURL) else { throw Container.DoesNotExistError() }

        try FileManager.default.removeItem(at: containerURL)
        containerURLs.remove(containerURL)
    }

    static func killAll(at urls: URL...) throws {
        let process: Process = .init()
        process.executableURL = Engine.directory.appending(path: "wine/bin/wineserver")
        process.arguments = ["-k"]

        let urls: [URL] = urls.isEmpty ? .init(containerURLs) : urls
        
        for url in urls {
            Task {
                process.environment = ["WINEPREFIX": url.path]
                process.qualityOfService = .utility
                
                try process.run()
            }
        }
    }

    static func purgeD3DMetalShaderCache() throws {
        let process: Process = .init()
        process.executableURL = .init(filePath: "/usr/bin/getconf")
        process.arguments = ["DARWIN_USER_CACHE_DIR"]

        let output = try process.runWrapped()
        
        guard let cachePath = output.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw CocoaError(.coderValueNotFound)
        }
        let d3dMetalCacheURL: URL = URL(filePath: cachePath).appendingPathComponent("d3dm")

        // although success may be limited, this is MUCH less risky than using applescript w/ string interpolation
        try FileManager.default.removeItem(at: d3dMetalCacheURL)
    }

    private static func addRegistryKey(containerURL: URL, key: String, name: String, data: String, type: RegistryType) async throws {
        guard containerExists(at: containerURL) else { throw Container.DoesNotExistError() }

        let process: Process = .init()
        process.arguments = ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"]
        transformProcess(process, containerURL: containerURL)
        
        try process.run()
        
        process.waitUntilExit()
        
        try process.checkTerminationStatus()
    }

    static func queryRegistryKey(containerURL: URL, key: String, name: String, type: RegistryType) async throws -> String {
        let process: Process = .init()
        process.arguments = ["reg", "query", key, "-v", name]
        transformProcess(process, containerURL: containerURL)
        
        let commandResult = try await process.runWrapped()

        try process.checkTerminationStatus()

        // Gather non-empty, trimmed lines; return the last occurrence
        let lines = commandResult.standardOutput?
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let last = lines?.last {
            return last
        } else {
            throw UnableToQueryRegistryError()
        }
    }

    static func toggleRetinaMode(containerURL: URL, toggle: Bool) async throws {
        do {
            try await addRegistryKey(containerURL: containerURL,
                                     key: RegistryKey.macDriver.rawValue,
                                     name: "RetinaMode",
                                     data: toggle ? "y" : "n",
                                     type: .string)

            // adjust display scaling accordingly; hard values of 192 and 96 seemingly work
            try await setDisplayScaling(containerURL: containerURL, dpi: toggle ? 192 : 96)
        } catch {
            log.error("\(formatLog(containerURL: containerURL, description: "Unable to toggle retina mode \(toggle)", error: error))")
            throw error
        }
    }

    static func getRetinaMode(containerURL: URL) async throws -> Bool {
        let result = try await queryRegistryKey(containerURL: containerURL,
                               key: RegistryKey.macDriver.rawValue,
                               name: "RetinaMode",
                               type: .string)

        return (result == "y")
    }

    static func getWindowsVersion(containerURL: URL) async throws -> WindowsVersion? {
        do {
            let process: Process = .init()
            process.arguments = ["winecfg", "-v"]
            transformProcess(process, containerURL: containerURL)
            
            let commandResult = try await process.runWrapped()
            
            let currentVersion: String?
            // wine above major version 7 sends the windows version to stderr
            if self.retrieveVersion()?.major ?? 0 > 7 {
                currentVersion = commandResult.standardError?
                    .split(whereSeparator: \.isNewline)
                    .last.map(String.init)
            } else {
                currentVersion = commandResult.standardOutput?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return WindowsVersion.allCases.first(where: { String(describing: $0) == currentVersion })
        } catch {
            log.error("\(formatLog(containerURL: containerURL, description: "Unable to get windows version", error: error))")
            throw error
        }
    }

    static func setWindowsVersion(containerURL: URL, version: WindowsVersion) async throws {
        do {
            let process: Process = .init()
            process.arguments = ["winecfg", "-v", String(describing: version)]
            transformProcess(process, containerURL: containerURL)
            
            try process.run()
            
            process.waitUntilExit()
            
            try process.checkTerminationStatus()
        } catch {
            log.error("\(formatLog(containerURL: containerURL, description: "Unable to set windows version", error: error))")
            throw error
        }
    }

    static func getDisplayScaling(containerURL: URL) async throws -> Int {
        do {
            let result = try await queryRegistryKey(containerURL: containerURL,
                                                    key: RegistryKey.desktop.rawValue,
                                                    name: "LogPixels",
                                                    type: .dword)

            guard let scale = Int(result.trimmingPrefix("0x"), radix: 16) else {
                return -1
            }

            return scale
        } catch {
            log.error("\(formatLog(containerURL: containerURL, description: "Unable to get display scaling value", error: error))")
            throw error
        }
    }

    static func setDisplayScaling(containerURL: URL, dpi: Int) async throws {
        guard (96...480).contains(dpi) else { return }
        do {
            try await addRegistryKey(containerURL: containerURL,
                                     key: RegistryKey.desktop.rawValue,
                                     name: "LogPixels",
                                     data: String(dpi),
                                     type: .dword)
        } catch {
            log.error("\(formatLog(containerURL: containerURL, description: "Unable to set display scaling value", error: error))")
            throw error
        }
    }
}
