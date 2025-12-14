//
//  LegendaryInterface.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 21/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import OSLog
import RegexBuilder

// FIXME: this code is on its way out. legendary will no longer be a Mythic dependency
/**
 Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities.
 ‼️ When adding any non-operation method, ensure you use the game's ID as a parameter, instead of the actual Game object.

 [Legendary GitHub Repository](https://github.com/derrod/legendary)
 */
final class Legendary {

    static let configurationFolder: URL = Bundle.appHome!.appending(path: "Epic")

    /// Logger instance for legendary.
    static let log: Logger = .custom(category: "LegendaryInterface")

    private static var legendaryExecutableURL: URL { Bundle.main.url(forResource: "legendary/cli", withExtension: nil)! }

    private static func constructEnvironment(withAdditionalFlags environment: [String: String] = .init()) -> [String: String] {
        var constructedEnvironment: [String: String] = .init()

        constructedEnvironment["LEGENDARY_CONFIG_PATH"] = configurationFolder.path

        return constructedEnvironment.merging(environment, uniquingKeysWith: { $1 })
    }

    @MainActor
    private static func applyOfflineFlagIfNeeded(_ currentArguments: [String]) -> [String] {
        var modifiedArguments = currentArguments
        if NetworkMonitor.shared.epicAccessibilityState != .accessible {
            modifiedArguments.append("--offline")
        }
        return modifiedArguments
    }
    
    ///
    /// - Note: This function will block until EOF.
    /// - Attention: This will only function if the process is currently executing.
    static func handleCLIErrorOutput(fromStandardErrorPipe pipe: Pipe) throws {
        guard let data: Data = try? pipe.fileHandleForReading.readToEnd(),
              let output: String = .init(data: data, encoding: .utf8) else { return }
        
        try handleCLIErrorOutput(fromStandardErrorOutput: output)
    }
    
    static func handleCLIErrorOutput(fromStandardErrorOutput output: String) throws {
        for line in output.split(whereSeparator: \.isNewline) {
            if let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: line),
               let errorReason = match.last?.substring {
                
                // TODO: dedicated handling for 'Failed to acquire installed data lock, only one instance of Legendary may install/import/move applications at a time.'
                throw GenericError(reason: String(errorReason))
            }
        }
    }

    /// Modify a process' properties to call `legendary`.
    /// This will modify `executableURL`, `arguments`, and `environment`, and passthrough existing values.
    static func transformProcess(_ process: Process) async {
        process.executableURL = legendaryExecutableURL
        
        let capturedArguments = process.arguments
        let arguments = await applyOfflineFlagIfNeeded(capturedArguments ?? [])
        process.arguments = arguments
        
        let capturedEnvironment = process.environment
        process.environment = constructEnvironment(withAdditionalFlags: capturedEnvironment ?? .init())
    }
    
    /// Execute a `Process` using `.runStreamed`.
    /// - Note: This is the recommended way to stream `legendary` output, as it automatically handles generic legendary errors.
    static func executeStreamed(_ process: Process,
                                throwsOnChunkError: Bool = true,
                                chunkHandler: @Sendable @escaping (Process.OutputChunk) throws -> String?) async throws {
        await transformProcess(process)
        
        try await process.runStreamed(
            throwsOnChunkError: throwsOnChunkError,
            chunkHandler: { chunk in
                if case .standardError = chunk.stream {
                    try handleCLIErrorOutput(fromStandardErrorOutput: chunk.output)
                }
                
                return try chunkHandler(chunk)
            }
        )
    }

    /// Parse legendary's DLManager status output, and use it to update a `Progress` object.
    private static func handleDownloadManagerOutputProgress(for output: String,
                                                            progress: Progress) {
        // these regexes are not dynamic, so there's no reason why they should fail to initialise
        // swiftlint:disable force_try
        let progressRegex: Regex = try! .init(#"Progress: (?<percentage>\d+\.\d+)% \((?<downloadedObjects>\d+)\/(?<totalObjects>\d+)\), Running for (?<runtime>\d+:\d+:\d+), ETA: (?<eta>\d+:\d+:\d+)"#)
        // let downloadRegex: Regex = try! .init(#"Downloaded: (?<downloaded>\d+\.\d+) \w+, Written: (?<written>\d+\.\d+) \w+"#)
        // let cacheRegex: Regex = try! .init(#"Cache usage: (?<usage>\d+\.\d+) \w+, active tasks: (?<activeTasks>\d+)"#)
        let downloadSpeedRegex: Regex = try! .init(#"\+ Download\s+- (?<raw>[\d.]+) \w+/\w+ \(raw\) / (?<decompressed>[\d.]+) \w+/\w+ \(decompressed\)"#)
        // let diskSpeedRegex: Regex = try! .init(#"\+ Disk\s+- (?<write>[\d.]+) \w+/\w+ \(write\) / (?<read>[\d.]+) \w+/\w+ \(read\)"#)
        // swiftlint:enable force_try

        /*
         SAMPLE LEGENDARY OUTPUT
         [DLManager] INFO: = Progress: 47.28% (261/552), Running for 00:00:14, ETA: 00:00:15
         [DLManager] INFO:  - Downloaded: 93.43 MiB, Written: 215.42 MiB
         [DLManager] INFO:  - Cache usage: 33.00 MiB, active tasks: 32
         [DLManager] INFO:  + Download    - 7.99 MiB/s (raw) / 17.00 MiB/s (decompressed)
         [DLManager] INFO:  + Disk    - 17.00 MiB/s (write) / 0.00 MiB/s (read)
         */

        if let match = try? progressRegex.firstMatch(in: output) {
            // an assumption is made that `.completedUnitCount` is set to 100.
            progress.completedUnitCount = Int64(Double(match["percentage"]?.substring ?? .init())?.rounded() ?? 0)

            progress.estimatedTimeRemaining = TimeInterval(HH_MM_SSString: String(match["eta"]?.substring ?? .init()))
            progress.fileCompletedCount = Int(match["downloadedObjects"]?.substring ?? .init()) ?? 0
            progress.fileTotalCount = Int(match["totalObjects"]?.substring ?? .init()) ?? 0
        }

        if let match = try? downloadSpeedRegex.firstMatch(in: output) {
            // convert raw download speed from MiB/s to B/s by multiplying by 1024^2
            progress.throughput = (Int(Double(match["raw"]?.substring ?? .init()) ?? 0)) * Int(pow(1024.0, 2.0))
        }

        // the others aren't really necessary, or useful information for endusers

        // for download speeds, use * pow(1024, 2), to convert from MiB to B
    }

    /*
     usage: legendary install <App Name> [options]

     Aliases: download, update

     positional arguments:
       <App Name>            Name of the app

     optional arguments:
       -h, --help            show this help message and exit
       --base-path <path>    Path for game installations (defaults to ~/Games)
       --game-folder <path>  Folder for game installation (defaults to folder specified in
                             metadata)
       --max-shared-memory <size>
                             Maximum amount of shared memory to use (in MiB), default: 1 GiB
       --max-workers <num>   Maximum amount of download workers, default: min(2 * CPUs, 16)
       --manifest <uri>      Manifest URL or path to use instead of the CDN one (e.g. for
                             downgrading)
       --old-manifest <uri>  Manifest URL or path to use as the old one (e.g. for testing
                             patching)
       --delta-manifest <uri>
                             Manifest URL or path to use as the delta one (e.g. for testing)
       --base-url <url>      Base URL to download from (e.g. to test or switch to a different
                             CDNs)
       --force               Download all files / ignore existing (overwrite)
       --disable-patching    Do not attempt to patch existing installation (download entire
                             changed files)
       --download-only, --no-install
                             Do not install app and do not run prerequisite installers after
                             download
       --update-only         Only update, do not do anything if specified app is not installed
       --dlm-debug           Set download manager and worker processes' loglevel to debug
       --platform <Platform>
                             Platform for install (default: installed or Windows)
       --prefix <prefix>     Only fetch files whose path starts with <prefix> (case
                             insensitive)
       --exclude <prefix>    Exclude files starting with <prefix> (case insensitive)
       --install-tag <tag>   Only download files with the specified install tag
       --enable-reordering   Enable reordering optimization to reduce RAM requirements during
                             download (may have adverse results for some titles)
       --dl-timeout <sec>    Connection timeout for downloader (default: 10 seconds)
       --save-path <path>    Set save game path to be used for sync-saves
       --repair              Repair installed game by checking and redownloading
                             corrupted/missing files
       --repair-and-update   Update game to the latest version when repairing
       --ignore-free-space   Do not abort if not enough free space is available
       --disable-delta-manifests
                             Do not use delta manifests when updating (may increase download
                             size)
       --reset-sdl           Reset selective downloading choices (requires repair to download
                             new components)
       --skip-sdl            Skip SDL prompt and continue with defaults (only required game
                             data)
       --disable-sdl         Disable selective downloading for title, reset existing
                             configuration (if any)
       --preferred-cdn <hostname>
                             Set the hostname of the preferred CDN to use when available
       --no-https            Download games via plaintext HTTP (like EGS), e.g. for use with a
                             lan cache
       --with-dlcs           Automatically install all DLCs with the base game
       --skip-dlcs           Do not ask about installing DLCs.
     */

    @discardableResult
    static func install(game: EpicGamesGame,
                        forPlatform platform: Game.Platform,
                        qualityOfService: QualityOfService,
                        optionalPackIDs: [String] = .init(),
                        baseDirectoryURL: URL? = UserDefaults.standard.url(forKey: "installBaseURL")) async throws -> GameOperation {
        guard let supportedPlatforms = game.getSupportedPlatforms(),
              supportedPlatforms.contains(platform) else {
            throw UnsupportedInstallationPlatformError()
        }

        var arguments: [String] = ["-y", "install", game.id]
        arguments += ["--platform", matchPlatform(for: platform)]

        guard let baseDirectoryURL = baseDirectoryURL else {
            log.error("Failed to infer default base URL, installation cannot continue")
            throw CocoaError(.fileReadUnknown)
        }
        arguments += ["--base-path", baseDirectoryURL.path]

        let operation: GameOperation = .init(game: game, type: .install) { [arguments] progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            let process: Process = .init()
            process.arguments = arguments
            
            try await withTaskCancellationHandler {
                try await executeStreamed(process) { chunk in
                    // append optional packs to legendary's stdin when it requests for them
                    if case .standardOutput = chunk.stream {
                        if chunk.output.contains("Additional packs"), !optionalPackIDs.isEmpty {
                            return optionalPackIDs.joined(separator: ", ") + "\n" // use \n as return key
                        }
                    }
                    
                    if case .standardError = chunk.stream {
                        handleDownloadManagerOutputProgress(for: chunk.output,
                                                            progress: progress)
                    }
                    
                    return nil
                }
            } onCancel: {
                process.interrupt()
            }
        }

        operation.qualityOfService = qualityOfService
        await Game.operationManager.queueOperation(operation)
        return operation
    }

    @discardableResult
    static func update(game: EpicGamesGame, qualityOfService: QualityOfService) async throws -> GameOperation {
        let arguments: [String] = ["-y", "install", game.id, "--update-only"]

        let operation: GameOperation = .init(game: game, type: .update) { progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            let process: Process = .init()
            process.arguments = arguments
            
            try await withTaskCancellationHandler {
                try await executeStreamed(process) { chunk in
                    if case .standardError = chunk.stream {
                        handleDownloadManagerOutputProgress(for: chunk.output,
                                                            progress: progress)
                    }
                    
                    return nil
                }
            } onCancel: {
                process.interrupt()
            }
        }

        operation.qualityOfService = qualityOfService
        await Game.operationManager.queueOperation(operation)
        return operation
    }

    @discardableResult
    static func repair(game: EpicGamesGame, qualityOfService: QualityOfService) async throws -> GameOperation {
        let arguments: [String] = ["-y", "install", game.id, "--repair"]

        let operation: GameOperation = .init(game: game, type: .repair) { progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            // note that throwsOnChunkError is disabled, as if a file does not match hash, a `GenericError` is thrown
            // due to the custom error handling in onChunkWithLegendaryErrorHandling.
            // thus, chunk errors are only acknowledged but not thrown.
            // this is bad though for obvious reasons
            let process: Process = .init()
            process.arguments = arguments
            
            try await withTaskCancellationHandler {
                try await executeStreamed(process, throwsOnChunkError: false) { chunk in
                    switch chunk.stream {
                    case .standardError:
                        // if game files require redownload
                        handleDownloadManagerOutputProgress(for: chunk.output,
                                                            progress: progress)
                    case .standardOutput:
                        // this regex is not dynamic, so there's no reason why they should fail to initialise
                        // swiftlint:disable force_try
                        let verificationProgressRegex = try! Regex(#"Verification progress: (?<downloadedObjects>\d+)\/(?<totalObjects>\d+) \((?<percentage>[\d.]+)%\) \[(?<rawDownloadSpeed>[\d.]+) MiB\/s\]"#)
                        // swiftlint:enable force_try
                        
                        /*
                         SAMPLE LEGENDARY OUTPUT
                         Verification progress: 18053/18780 (98.7%) [1020.6 MiB/s] // main progress
                         => Verifying large file "TAGame/CookedPCConsole/Textures3.tfc": 45% (1151.0/2576.2 MiB) [1186.8 MiB/s] // progress for large files (unhandled)
                         */
                        
                        if let match = try? verificationProgressRegex.firstMatch(in: chunk.output) {
                            progress.completedUnitCount = Int64(Double(match["percentage"]?.substring ?? .init())?.rounded() ?? 0)
                            progress.fileCompletedCount = Int(match["downloadedObjects"]?.substring ?? .init()) ?? 0
                            progress.fileTotalCount = Int(match["totalObjects"]?.substring ?? .init()) ?? 0
                            
                            // convert raw download speed from MiB/s to B/s by multiplying by 1024^2
                            progress.throughput = (Int(Double(match["rawDownloadSpeed"]?.substring ?? .init()) ?? 0)) * Int(pow(1024.0, 2.0))
                        }
                    }
                    
                    return nil
                }
            } onCancel: {
                process.interrupt()
            }
        }

        operation.qualityOfService = qualityOfService
        await Game.operationManager.queueOperation(operation)
        return operation
    }

    /*
     usage: legendary uninstall [-h] [--keep-files] [--skip-uninstaller] <App Name>

     positional arguments:
       <App Name>          Name of the app

     optional arguments:
       -h, --help          show this help message and exit
       --keep-files        Keep files but remove game from Legendary database
       --skip-uninstaller  Skip running the uninstaller
     */
    @discardableResult
    static func uninstall(game: EpicGamesGame,
                          persistFiles: Bool,
                          runUninstallerIfPossible: Bool = true) async throws -> GameOperation {
        let operation: GameOperation = .init(game: game, type: .uninstall) { _ in
            var arguments: [String] = ["-y", "uninstall", game.id]

            if persistFiles { arguments.append("--keep-files") }
            if !runUninstallerIfPossible { arguments.append("--skip-uninstaller") }

            // legendary is inconsistent with this,
            // may have to use FileManager.default.removeItem(atPath:)
            let process: Process = .init()
            process.arguments = arguments
            await transformProcess(process)
            
            let processStandardErrorPipe: Pipe = .init()
            process.standardError = processStandardErrorPipe
            
            try process.run()
            
            try handleCLIErrorOutput(fromStandardErrorPipe: processStandardErrorPipe)
            
            // FIXME: not ideal, initialiser states no installationstate should be .uninstalled
            // FIXME: ideally, destroy the game object somehow
            game.installationState = .uninstalled
        }

        await Game.operationManager.queueOperation(operation)
        return operation
    }

    /*
     usage: legendary move [-h] [--skip-move] <App Name> <New Base Path>

     positional arguments:
       <App Name>       Name of the app
       <New Base Path>  Directory to move game folder to

     optional arguments:
       -h, --help       show this help message and exit
       --skip-move      Only change legendary database, do not move files (e.g. if
                        already moved)
     */
    @discardableResult
    static func move(game: EpicGamesGame, to newLocation: URL) async throws -> GameOperation {
        guard case .installed(let currentLocation, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let operation: GameOperation = .init(game: game, type: .move) { _ in
            try FileManager.default.moveItem(at: currentLocation, to: newLocation)

            let process: Process = .init()
            process.arguments = ["move", game.id, newLocation.path, "--skip-move"]
            await transformProcess(process)
            
            let processStandardErrorPipe: Pipe = .init()
            process.standardError = processStandardErrorPipe
            
            try process.run()
            
            try handleCLIErrorOutput(fromStandardErrorPipe: processStandardErrorPipe)
            
            game.installationState = .installed(location: newLocation, platform: platform)
        }

        await Game.operationManager.queueOperation(operation)
        return operation
    }

    /*
     usage: legendary import [-h] [--disable-check] [--with-dlcs] [--skip-dlcs]
                             [--platform <Platform>]
                             <App Name> <Installation directory>

     positional arguments:
       <App Name>            Name of the app
       <Installation directory>
                             Path where the game is installed

     optional arguments:
       -h, --help            show this help message and exit
       --disable-check       Disables completeness check of the to-be-imported game
                             installation (useful if the imported game is a much older version
                             or missing files)
       --with-dlcs           Automatically attempt to import all DLCs with the base game
       --skip-dlcs           Do not ask about importing DLCs.
       --platform <Platform>
                             Platform for import (default: Mac on macOS, otherwise Windows)
     */
    @MainActor static func importGame(_ game: EpicGamesGame,
                                      in enclosingDirectory: URL,
                                      repairIfNecessary: Bool = true,
                                      withDLCs: Bool = true,
                                      platform: Game.Platform) async throws {
        guard let supportedPlatforms = game.getSupportedPlatforms(),
              supportedPlatforms.contains(platform) else {
            throw UnsupportedInstallationPlatformError()
        }

        var arguments: [String] = ["-y", "import"]

        if !repairIfNecessary { arguments.append("--disable-check") }
        if withDLCs { arguments.append("--with-dlcs") } else { arguments.append("--skip-dlcs") }

        // append arguments in order, as specified by legendary's '--help' argument
        arguments += ["--platform", matchPlatform(for: platform)]
        arguments.append(game.id)

        arguments.append(enclosingDirectory.path)
        
        let process: Process = .init()
        process.arguments = arguments
        await transformProcess(process)
        
        let processStandardErrorPipe: Pipe = .init()
        process.standardError = processStandardErrorPipe
        
        try process.run()
        
        try handleCLIErrorOutput(fromStandardErrorPipe: processStandardErrorPipe)
    }

    @discardableResult
    static func signIn(authKey: String) async throws -> String {
        let process: Process = .init()
        process.arguments = ["auth", "--code", authKey]
        await transformProcess(process)
        
        let result = try await process.runWrapped()
        
        if let successRegex = try? Regex(#"Successfully logged in as \"(?<username>[^\"]+)\""#),
           let standardError = result.standardError,
           let match = try? successRegex.firstMatch(in: standardError),
           let username = match["username"]?.substring {
            // refresh failure should not affect signin capability
            try? await GameDataStore.shared.refreshFromStorefronts()
            return String(username)
        }

        throw SignInError()
    }

    static func signOut() async throws {
        let process: Process = .init()
        process.arguments = ["auth", "--delete"]
        await transformProcess(process)
        
        let processStandardErrorPipe: Pipe = .init()
        process.standardError = processStandardErrorPipe
        
        try process.run()
        
        try handleCLIErrorOutput(fromStandardErrorPipe: processStandardErrorPipe)
        
        UserDefaults.standard.removeObject(forKey: "epicGamesWebDataStore")
    }

    /**
     Launches games.
     */
    @discardableResult
    static func launch(game: EpicGamesGame) async throws -> GameOperation {
        guard case .installed(_, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let operation: GameOperation = .init(game: game, type: .launch) { _ in
            guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }

            var arguments: [String] = ["launch", game.id]
            var environment: [String: String] = .init()

            guard game.isFileVerificationRequired != true else { throw EpicGamesGame.VerificationRequiredError() }

            // uses legendary's native launch process
            switch platform {
            case .macOS:
                do {} // no environment variables need to be assembled.
            case .windows:
                environment = try Wine.assembleEnvironmentVariables(forContainer: containerURL)
                // legendary requires this, since it calls wine directly.
                environment["WINEPREFIX"] = containerURL.path(percentEncoded: false)

                arguments += ["--wine", Engine.wineExecutableURL.path]
            }

            arguments.append(contentsOf: game.launchArguments.map({ "'\($0)'" }))

            let process: Process = .init()
            process.arguments = arguments
            process.environment = environment
            await transformProcess(process)
            
            let processStandardErrorPipe: Pipe = .init()
            process.standardError = processStandardErrorPipe
            
            try await withTaskCancellationHandler {
                try process.run()
                
                try handleCLIErrorOutput(fromStandardErrorPipe: processStandardErrorPipe)
            } onCancel: {
                process.interrupt()
            }
        }

        await Game.operationManager.queueOperation(operation)
        return operation
    }

    static func fetchUpdateAvailability(gameID: String) throws -> Bool {
        let metadata = try getGameMetadata(gameID: gameID)
        let installationData = try getGameInstallationData(gameID: gameID)

        guard let assetInfo = metadata.assetInfos[installationData._platform] else {
            throw CocoaError(.coderValueNotFound)
        }

        // it would be more ideal checking if upstreamVersion is greater than
        // installedVersion, but to do that, we'd need to convert them into
        // SemanticVersion, which is problematic because we have no guarantee
        // that the game uses semantic versioning.
        return assetInfo.buildVersion != installationData.version
    }

    static func fetchPreInstallationMetadata(
        game: EpicGamesGame,
        platform: Game.Platform
    ) async throws -> (installSize: Int64?, optionalPacks: [String: String]) {
        guard case .uninstalled = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let arguments: [String] = ["install", game.id, "--platform", matchPlatform(for: platform)]
        
        var installSize: Int64?
        var optionalPacks: [String: String] = .init()

        // if the data lock is present, legendary will terminate itself, so this is ok
        // nice n safe
        let process: Process = .init()
        process.arguments = arguments
        
        // note that install size and optional packs are mutually exclusive in this context.
        try await withTaskCancellationHandler {
            try await executeStreamed(process) { chunk in
                switch chunk.stream {
                case .standardError:
                    // Handle install size
                    Task {
                        // legendary always returns install size in MiB
                        if let match = try? Regex(#"Install size: (\d+(?:\.\d+)?) MiB"#).firstMatch(in: chunk.output),
                           let sizeString = match[1].substring,
                           let sizeValue = Double(sizeString) {
                            await MainActor.run {
                                installSize = Int64(Int(sizeValue) * 1_048_576) // MiB ➜ B
                                
                                process.interrupt()
                            }
                        }
                    }
                    
                case .standardOutput:
                    // Handle optional packs
                    Task { @MainActor in
                        if let match = try? Regex(#"\s*\* (?<identifier>\w+) - (?<name>.+)"#).firstMatch(in: chunk.output),
                           let id = match["identifier"]?.substring,
                           let name = match["name"]?.substring {
                            optionalPacks[String(id)] = String(name)
                        }
                    }
                    
                    if chunk.output.contains("Please enter tags of pack(s) to install") {
                        process.interrupt()
                    }
                    
                    // Handle installation requirements check results
                    /* TODO: not implemented, may be unnecessary
                     if chunk.output.contains(" - Warning:") {
                     
                     }
                     
                     if chunk.output.contains(" ! Failure:") {
                     
                     }
                     */
                }
                
                return nil
            }
        } onCancel: {
            process.interrupt()
        }
        
        return (installSize, optionalPacks)
    }

    static func isFileVerificationRequired(gameID: String) throws -> Bool {
        let installationData = try getGameInstallationData(gameID: gameID)
        return installationData.needsVerification
    }

    /// Queries for the user that is currently signed into epic games.
    static func retrieveUser() throws -> String? {
        let userURL: URL = configurationFolder.appending(path: "user.json")
        
        guard let userData = try? Data(contentsOf: userURL),
              let userObject = try? JSONDecoder().decode(User.self, from: userData) else {
            return nil
        }

        return userObject.displayName
    }

    /// Checks account signin state.
    static var isSignedIn: Bool { return (try? retrieveUser()) != nil }

    static func getInstalledGames() throws -> [EpicGamesGame] {
        guard isSignedIn else { throw NotSignedInError() }

        let installedJSONURL: URL = configurationFolder.appending(path: "installed.json")
        
        // if no games are installed, and the config folder is new, installed.json will not exist.
        guard FileManager.default.fileExists(atPath: installedJSONURL.path) else { return [] }
        
        let installedJSONData = try Data(contentsOf: installedJSONURL)
        let installedGames = try JSONDecoder().decode(Installed.self, from: installedJSONData)

        return installedGames.compactMap { (id, installedGame) -> EpicGamesGame? in
            guard let platform: Game.Platform = installedGame.platform else { return nil }
            
            return .init(
                id: id,
                title: installedGame.title,
                installationState: .installed(location: .init(filePath: installedGame.installPath),
                                              platform: platform)
            )
        }
    }

    static func getInstallableGames() throws -> [EpicGamesGame] {
        guard isSignedIn else { throw NotSignedInError() }

        let metadataDirectory: URL = configurationFolder.appending(path: "metadata")

        return try {
            try FileManager.default.contentsOfDirectory(atPath: metadataDirectory.path).map { fileName -> EpicGamesGame in
                let data = try Data(contentsOf: metadataDirectory.appending(path: fileName))
                let metadata = try JSONDecoder().decode(GameMetadata.self, from: data)

                let game: EpicGamesGame = .init(id: metadata.appName,
                                                title: metadata.appTitle,
                                                installationState: .uninstalled)

                return game
            }
        }()
    }

    static func getGameMetadata(gameID: String) throws -> GameMetadata {
        let metadataDirectory: URL = configurationFolder.appending(path: "metadata")
        let metadataDirectoryContents = try FileManager.default.contentsOfDirectory(atPath: metadataDirectory.path)

        guard let metadataFileName: String = metadataDirectoryContents.first(where: { $0 == gameID.appending(".json") }) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data: Data = try .init(contentsOf: URL(filePath: metadataDirectory.appending(path: metadataFileName).path))
        let metadata: GameMetadata = try JSONDecoder().decode(GameMetadata.self, from: data)

        return metadata
    }

    static func getGameInstallationData(gameID: String) throws -> InstalledGame {
        let installedJSONURL: URL = configurationFolder.appending(path: "installed.json")
        let installedJSONData: Data = try .init(contentsOf: installedJSONURL)
        let installedGames = try JSONDecoder().decode(Installed.self, from: installedJSONData)

        guard let installedGame = installedGames[gameID] else { throw CocoaError(.coderValueNotFound) }

        return installedGame
    }

    /**
     Retrieve a game's launch arguments from Legendary's `installed.json` file.
     ** This isn't compatible with Mythic'c current launch argument implementation, and likely will remain in this unimplemented state.
     */
    static func getGameLaunchParameters(gameID: String) throws -> [String] {
        let installationData = try getGameInstallationData(gameID: gameID)

        // FIXME: unverified that this is how it's implemented in Legendary
        return installationData.launchParameters.components(separatedBy: .whitespaces)
    }

    // TODO: refactor
    /// Create an asynchronous task to update Legendary's stored metadata.
    static func updateMetadata(forced: Bool = true) async {
        guard await !GameListViewModel.shared.isUpdatingLibrary else { return }
        var arguments: [String] = ["list"]
        if forced { arguments.append("--force-refresh") }
        
        Task {
            await MainActor.run {
                GameListViewModel.shared.isUpdatingLibrary = true
            }
            
            defer {
                Task { @MainActor in
                    GameListViewModel.shared.isUpdatingLibrary = false
                }
            }
            
            let process: Process = .init()
            process.arguments = arguments
            await transformProcess(process)
            
            try process.run()
            
            await withCheckedContinuation { continuation in
                process.waitUntilExit()
                continuation.resume()
            }
        }
    }
    
    static func getImageMetadata(gameID: String, type: ImageType) -> KeyImage? {
        guard let metadata = try? getGameMetadata(gameID: gameID) else { return nil }

        let keyImages = metadata.storeMetadata.keyImages

        let prioritisedTypes: [String] = {
            switch type {
            case .normal: return ["DieselGameBoxWide", "DieselGameBox"]
            case .tall: return ["DieselGameBoxTall"]
            }
        }()

        return keyImages.first(where: { prioritisedTypes.contains($0.type) })
    }

    // TODO: CodingKeys
    static func matchPlatformString(for string: String) -> Game.Platform? {
        switch string {
        case "Windows": .windows
        case "Mac":     .macOS
        default:        nil
        }
    }

    // TODO: CodingKeys
    static func matchPlatform(for platform: Game.Platform) -> String {
        switch platform {
        case .windows:  "Windows"
        case .macOS:    "Mac"
        }
    }

    /// Retrieves game thumbnail image from legendary's downloaded metadata.
    static func getImageURL(gameID: String, type: ImageType) -> URL? {
        if let imageMetadata = getImageMetadata(gameID: gameID, type: type) {
            return .init(string: imageMetadata.url)
        }

        // fallback #1 — attempt to fetch best matching image for specified image type
        guard let metadata = try? getGameMetadata(gameID: gameID) else { return nil }
        let keyImages = metadata.storeMetadata.keyImages

        if let bestImageMetadata = keyImages.first(where: {
            (type == .normal && $0.width >= $0.height) || (type == .tall && $0.height > $0.width)
        }) {
            return .init(string: bestImageMetadata.url)
        }

        // fallback #2 — use any available image
        if let firstKeyImage = keyImages.first {
            return .init(string: firstKeyImage.url)
        }

        // fallback #3 — 🪦
        return nil
    }

    // don't use or at least refactor 💔 i could not code back in 2023
    static func isAlias(game: String) throws -> (Bool?, of: String?) {
        guard isSignedIn else { throw NotSignedInError() }

        let aliasesFile: URL = configurationFolder.appending(path: "aliases.json")
        let aliasesData = try Data(contentsOf: aliasesFile)

        guard let aliases = try? JSONDecoder().decode(Aliases.self, from: aliasesData) else {
            return (nil, of: nil)
        }

        for (id, aliasList) in aliases {
            if id == game || aliasList.contains(game) {
                return (true, of: id)
            }
        }

        return (nil, of: nil)
    }
}
