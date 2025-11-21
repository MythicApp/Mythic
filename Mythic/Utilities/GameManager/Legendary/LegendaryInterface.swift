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
import UserNotifications
import RegexBuilder

/**
 Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities.

 [Legendary GitHub Repository](https://github.com/derrod/legendary)
 */
// FIXME: this code is on its way out. legendary will no longer be a Mythic dependency
final class Legendary {

    static let configurationFolder: URL = Bundle.appHome!.appending(path: "Epic")

    /// Logger instance for legendary.
    static let log: Logger = .custom(category: "LegendaryInterface")

    // Minimal registry for running consumer tasks (cancel stops process via Process.stream cancellation)
    actor RunningCommands {
        static let shared: RunningCommands = .init()

        private var tasks: [String: Task<Void, Error>] = [:]

        func set(id: String, task: Task<Void, Error>) {
            tasks[id] = task
        }

        fileprivate func remove(id: String) {
            tasks.removeValue(forKey: id)
        }

        func stop(id: String) {
            if let task = tasks[id] {
                task.cancel()
                remove(id: id)
            }
        }

        func stopAll() {
            tasks.values.forEach { $0.cancel() }
            tasks.removeAll()
        }
    }

    private static var legendaryExecutableURL: URL { Bundle.main.url(forResource: "legendary/cli", withExtension: nil)! }

    private static func constructEnvironment(withAdditionalFlags environment: [String: String]?) -> [String: String] {
        var constructedEnvironment: [String: String] = .init()

        constructedEnvironment["LEGENDARY_CONFIG_PATH"] = configurationFolder.path

        if let environment = environment {
            constructedEnvironment.merge(environment, uniquingKeysWith: { $1 })
        }

        return constructedEnvironment
    }

    @MainActor
    private static func applyOfflineFlagIfNeeded(_ currentArguments: [String]) -> [String] {
        var modifiedArguments = currentArguments
        if NetworkMonitor.shared.epicAccessibilityState != .accessible {
            modifiedArguments.append("--offline")
        }
        return modifiedArguments
    }

    private static func onChunkWithLegendaryErrorHandling(
        _ onChunk: (@Sendable (Process.OutputChunk) throws -> String?)?
    ) -> (@Sendable (Process.OutputChunk) throws -> String?)? {
        guard let onChunk = onChunk else { return nil }
        return { chunk in
            // handle and throw generic Legendary errors
            if case .standardError = chunk.stream,
               let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: chunk.output),
               let errorReason = match.last?.substring {
                throw Legendary.GenericError(reason: String(errorReason))
            }

            return try onChunk(chunk)
        }
    }

    @discardableResult
    static func execute(
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> Process.CommandResult {
        let args = await applyOfflineFlagIfNeeded(arguments)
        return try await Process.executeAsync(
            executableURL: legendaryExecutableURL,
            arguments: args,
            environment: constructEnvironment(withAdditionalFlags: environment),
            currentDirectoryURL: currentDirectoryURL
        )
    }

    private static func startStream(
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        onChunk: (@Sendable (Process.OutputChunk) throws -> String?)? = nil
    ) -> AsyncThrowingStream<Process.OutputChunk, Error> {
        let env = constructEnvironment(withAdditionalFlags: environment)
        return Process.stream(
            executableURL: legendaryExecutableURL,
            arguments: arguments,
            environment: env,
            currentDirectoryURL: currentDirectoryURL,
            onChunk: onChunkWithLegendaryErrorHandling(onChunk)
        )
    }

    @discardableResult
    static func executeStreamed(
        identifier: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        onChunk: @Sendable @escaping (Process.OutputChunk) throws -> String?
    ) async -> Task<Void, Error> {
        let consumer = Task {
            let args = await applyOfflineFlagIfNeeded(arguments)
            let stream = startStream(
                arguments: args,
                environment: environment,
                currentDirectoryURL: currentDirectoryURL,
                onChunk: onChunk
            )

            do {
                for try await _ in stream {
                    // work handled in onChunk
                }
            } catch is CancellationError {
                // expected when cancelled via RunningCommands.stop(id:)
                // since it relies on `Task` cancellation
                do {}
            } catch {
                throw error
            }

            // clean up tracking after completion/cancellation/error
            await RunningCommands.shared.remove(id: identifier)
        }

        await RunningCommands.shared.set(id: identifier, task: consumer)
        return consumer
    }

    /// Parse legendary's DLManager status output, and use it to update a `Progress` object.
    private static func handleDownloadManagerOutputProgress(for output: String,
                                                            progress: Progress) {
        // these regexes are not dynamic, so there's no reason why they should fail to initialise
        // swiftlint:disable force_try
        let progressRegex: Regex = try! .init(#"Progress: (?<percentage>\d+\.\d+)% \((?<downloadedObjects>\d+)\/(?<totalObjects>\d+)\), Running for (?<runtime>\d+:\d+:\d+), ETA: (?<eta>\d+:\d+:\d+)"#)
        let downloadRegex: Regex = try! .init(#"Downloaded: (?<downloaded>\d+\.\d+) \w+, Written: (?<written>\d+\.\d+) \w+"#)
        let cacheRegex: Regex = try! .init(#"Cache usage: (?<usage>\d+\.\d+) \w+, active tasks: (?<activeTasks>\d+)"#)
        let downloadSpeedRegex: Regex = try! .init(#"\+ Download\s+- (?<raw>[\d.]+) \w+/\w+ \(raw\) / (?<decompressed>[\d.]+) \w+/\w+ \(decompressed\)"#)
        let diskSpeedRegex: Regex = try! .init(#"\+ Disk\s+- (?<write>[\d.]+) \w+/\w+ \(write\) / (?<read>[\d.]+) \w+/\w+ \(read\)"#)
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
            progress.completedUnitCount = Int64(match["percentage"]?.substring ?? .init()) ?? 0

            progress.estimatedTimeRemaining = TimeInterval(HH_MM_SSString: String(match["eta"]?.substring ?? .init()))
            progress.fileCompletedCount = Int(match["downloadedObjects"]?.substring ?? .init()) ?? 0
            progress.fileTotalCount = Int(match["totalObjects"]?.substring ?? .init()) ?? 0
        }

        if let match = try? downloadSpeedRegex.firstMatch(in: output) {
            // convert raw download speed from MiB/s to B/s by multiplying by 1024^2
            progress.throughput = (Int(match["rawDownloadSpeed"]?.substring ?? .init()) ?? 0) * Int(pow(1024.0, 2.0))
        }

        // the others aren't really necessary, or useful information for endusers

        // for download speeds, use * pow(1024, 2), to convert from MiB to B
    }

    static func install(game: EpicGamesGame,
                        forPlatform platform: Game.Platform,
                        qos: QualityOfService,
                        optionalPacks: [String] = .init(),
                        gameDirectoryURL: URL? = Bundle.appGames) async throws {
        guard game.supportedPlatforms.contains(platform) else {
            throw UnsupportedInstallationPlatformError()
        }
        var arguments: [String] = ["-y", "install", game.id]
        arguments += ["--platform", matchPlatform(for: platform)]

        guard let gameDirectoryURL = gameDirectoryURL else {
            log.error("Failed to infer default base URL, installation cannot continue")
            throw CocoaError(.fileReadUnknown)
        }
        arguments += ["--game-folder", gameDirectoryURL.path]

        let operation: GameOperation = .init(game: game, type: .install) { [arguments] progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            let consumer = await Legendary.executeStreamed(identifier: "install",
                                                           arguments: arguments) { chunk in
                // append optional packs to legendary's stdin when it requests for them
                if case .standardOutput = chunk.stream {
                    if chunk.output.contains("Additional packs"), !optionalPacks.isEmpty {
                        return optionalPacks.joined(separator: ", ") + "\n" // use \n as return key
                    }
                }

                if case .standardError = chunk.stream {
                    handleDownloadManagerOutputProgress(for: chunk.output,
                                                        progress: progress)
                }

                return nil
            }
        }

        await Game.operationManager.queueOperation(operation)
    }

    static func update(game: EpicGamesGame, qos: QualityOfService) async throws {
        let arguments: [String] = ["-y", "install", game.id, "--update-only"]

        let operation: GameOperation = .init(game: game, type: .update) { progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            let consumer = await Legendary.executeStreamed(identifier: "update",
                                                           arguments: arguments) { chunk in
                if case .standardError = chunk.stream {
                    handleDownloadManagerOutputProgress(for: chunk.output,
                                                        progress: progress)
                }

                return nil
            }
        }

        await Game.operationManager.queueOperation(operation)
    }

    static func repair(game: EpicGamesGame, qos: QualityOfService) async throws {
        let arguments: [String] = ["-y", "install", game.id, "--repair"]

        let operation: GameOperation = .init(game: game, type: .repair) { progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            let consumer = await Legendary.executeStreamed(identifier: "repair",
                                                           arguments: arguments) { chunk in
                if case .standardOutput = chunk.stream {
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
                        progress.completedUnitCount = Int64(match["percentage"]?.substring ?? .init()) ?? 0
                        progress.fileCompletedCount = Int(match["downloadedObjects"]?.substring ?? .init()) ?? 0
                        progress.fileTotalCount = Int(match["totalObjects"]?.substring ?? .init()) ?? 0

                        // convert raw download speed from MiB/s to B/s by multiplying by 1024^2
                        progress.throughput = (Int(match["rawDownloadSpeed"]?.substring ?? .init()) ?? 0) * Int(pow(1024.0, 2.0))
                    }
                }
                return nil
            }
        }

        await Game.operationManager.queueOperation(operation)
    }

    static func uninstall(game: EpicGamesGame,
                          persistFiles: Bool,
                          runUninstallerIfPossible: Bool = true) async throws {
        let operation: GameOperation = .init(game: game, type: .uninstall) { _ in
            var arguments: [String] = ["-y", "uninstall", game.id]

            if persistFiles { arguments += ["--keep-files"] }
            if !runUninstallerIfPossible { arguments += ["--skip-uninstaller"] }

            // legendary is inconsistent with this,
            // may have to use files.removeItem(atPath:)
            try await Legendary.execute(arguments: arguments)
        }

        await Game.operationManager.queueOperation(operation)
    }

    @MainActor static func move(game: EpicGamesGame, to newLocation: URL) async throws {
        guard case .installed(let currentLocation, _) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let operation: GameOperation = .init(game: game, type: .move) { _ in
            try files.moveItem(at: currentLocation, to: newLocation)

            try await Legendary.execute(arguments: ["move", game.id, newLocation.path, "--skip-move"])
        }

        Game.operationManager.queueOperation(operation)
    }

    @discardableResult
    static func signIn(authKey: String) async throws -> String {
        let result = try await execute(arguments: ["auth", "--code", authKey])
        if let match = try? Regex(#"Successfully logged in as \"(?<username>[^\"]+)\""#).firstMatch(in: result.standardError),
           let username = match["username"]?.substring {
            await GameListViewModel.shared.refresh()
            return String(username)
        }
        throw SignInError()
    }

    static func signOut() async throws {
        _ = try await execute(arguments: ["auth", "--delete"])
        defaults.removeObject(forKey: "epicGamesWebDataStoreIdentifierString")
    }

    /**
     Launches games.
     */
    @MainActor static func launch(game: EpicGamesGame) async throws {
        guard case .installed(_, let platform) = game.installationState else {
            throw CocoaError(.fileNoSuchFile)
        }

        let operation: GameOperation = .init(game: game, type: .launch) { progress in
            guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }

            var arguments: [String] = ["launch", game.id]
            var environment: [String: String] = .init()

            guard game.isFileVerificationRequired != true else { throw EpicGamesGame.VerificationRequiredError() }

            // uses legendary's native launch process
            switch platform {
            case .macOS:
                do {} // no environment variable need to be assembled.
            case .windows:
                environment = try Wine.assembleEnvironmentVariables(forContainer: containerURL)
                // legendary requires this, since it calls wine directly.
                environment["WINEPREFIX"] = containerURL.path(percentEncoded: false)

                arguments += ["--wine", Engine.wineExecutableURL.path]
            }

            arguments.append(contentsOf: game.launchArguments.map({ "'\($0)'" }))

            try await Legendary.execute(arguments: arguments,
                                        environment: environment)
        }

        Game.operationManager.queueOperation(operation)
    }

    // MARK: Get Game Platform Method

    static func getGamePlatform(game: EpicGamesGame) throws -> EpicGamesGame.Platform? {
        let installedData: URL = configurationFolder.appending(path: "installed.json")
        let data: Data = try .init(contentsOf: installedData)
        let installedGames = try JSONDecoder().decode(Installed.self, from: data)

        guard let installedGame = installedGames[game.id] else {
            throw UnableToRetrieveError()
        }

        return installedGame.platform
    }

    static func fetchUpdateAvailability(for game: EpicGamesGame) throws -> Bool {
        let metadata = try Legendary.getGameMetadata(game: game)

        let installedJSONURL: URL = Legendary.configurationFolder.appending(path: "installed.json")
        let installedJSONData: Data = try .init(contentsOf: installedJSONURL)
        let installedGames = try JSONDecoder().decode(Installed.self, from: installedJSONData)

        guard
            let installedGame = installedGames[game.id],
            let assetInfo = metadata.assetInfos[installedGame._platform]
        else {
            throw CocoaError(.coderValueNotFound)
        }

        // it would be more ideal checking if upstreamVersion is greater than
        // installedVersion, but to do that, we'd need to convert them into
        // SemanticVersion, which is problematic because we have no guarantee
        // that the game uses semantic versioning.
        return assetInfo.buildVersion != installedGame.version
    }

    static func isFileVerificationRequired(for game: EpicGamesGame) throws -> Bool {
        let installedJSONURL: URL = Legendary.configurationFolder.appending(path: "installed.json")
        let installedJSONData: Data = try .init(contentsOf: installedJSONURL)
        let installedGames = try JSONDecoder().decode(Installed.self, from: installedJSONData)

        return installedGames[game.id]?.needsVerification ?? false
    }

    /// Queries for the user that is currently signed into epic games.
    static var user: String? {
        let userURL: URL = configurationFolder.appending(path: "user.json")
        guard let userData = try? Data(contentsOf: userURL),
              let userObject = try? JSONDecoder().decode(User.self, from: userData) else {
            return nil
        }

        return userObject.displayName
    }

    /// Checks account signin state.
    static var signedIn: Bool { return user != nil }

    static func getInstalledGames() throws -> [EpicGamesGame] {
        guard signedIn else { throw NotSignedInError() }

        let installedData = configurationFolder.appending(path: "installed.json")
        let data = try Data(contentsOf: installedData)
        let installedGames = try JSONDecoder().decode(Installed.self, from: data)

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

    static func getGamePath(game: EpicGamesGame) throws -> String? {
        guard signedIn else { throw NotSignedInError() }

        let installedData = try Data(contentsOf: configurationFolder.appending(path: "installed.json"))
        let installed = try JSONDecoder().decode(Installed.self, from: installedData)
        return installed[game.id]?.installPath
    }

    static func getInstallableGames() throws -> [EpicGamesGame] {
        guard signedIn else { throw NotSignedInError() }

        let metadataDirectory: URL = configurationFolder.appending(path: "metadata")

        let games = try files.contentsOfDirectory(atPath: metadataDirectory.path).map { fileName -> EpicGamesGame in
            let data = try Data(contentsOf: metadataDirectory.appending(path: fileName))
            let metadata = try JSONDecoder().decode(GameMetadata.self, from: data)

            var game: EpicGamesGame = .init(id: metadata.appName,
                                            title: metadata.appTitle,
                                            installationState: .uninstalled)

            let dateFormatter: ISO8601DateFormatter = .init()
            let latestGameRelease = metadata.storeMetadata.releaseInfo
                .max(by: { $0.dateAdded < $1.dateAdded })

            game.supportedPlatforms = latestGameRelease?.platform ?? .init()

            return game
        }

        return games.sorted { $0.title < $1.title }
    }

    static func getGameMetadata(game: EpicGamesGame) throws -> GameMetadata {
        let metadataDirectory: URL = configurationFolder.appending(path: "metadata")
        let metadataDirectoryContents = try files.contentsOfDirectory(atPath: metadataDirectory.path)

        guard let metadataFileName: String = metadataDirectoryContents.first(where: { $0 == "\(game.id).json" }) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data: Data = try .init(contentsOf: URL(filePath: metadataDirectory.appending(path: metadataFileName).path))
        let metadata: GameMetadata = try JSONDecoder().decode(GameMetadata.self, from: data)

        return metadata
    }

    /**
     Retrieve a game's launch arguments from Legendary's `installed.json` file.
     ** This isn't compatible with Mythic'c current launch argument implementation, and likely will remain in this unimplemented state.
     */
    static func getGameLaunchArguments(game: EpicGamesGame) throws -> [String] {
        let installedData = try Data(contentsOf: configurationFolder.appending(path: "installed.json"))
        let installed = try JSONDecoder().decode(Installed.self, from: installedData)

        guard let installedGame = installed[game.id] else {
            throw UnableToRetrieveError()
        }

        return installedGame.launchParameters.components(separatedBy: .whitespaces)
    }

    /// Create an asynchronous task to update Legendary's stored metadata.
    @MainActor static func updateMetadata(forced: Bool = false) {
        if VariableManager.shared.getVariable("isUpdatingLibrary") != true {
            var arguments: [String] = ["list"]
            if forced { arguments.append("--force-refresh") }
            Task(priority: .utility) { @MainActor in
                VariableManager.shared.setVariable("isUpdatingLibrary", value: true)
                _ = try? await execute(arguments: arguments)
                VariableManager.shared.setVariable("isUpdatingLibrary", value: false)
            }
        }
    }

    static func getImageMetadata(for game: EpicGamesGame, type: ImageType) -> KeyImage? {
        guard let metadata = try? getGameMetadata(game: game) else { return nil }

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
    static func getImageURL(of game: EpicGamesGame, type: ImageType) -> URL? {
        if let imageMetadata = getImageMetadata(for: game, type: type) {
            return .init(string: imageMetadata.url)
        }

        // fallback #1 — attempt to fetch best matching image for specified image type
        guard let metadata = try? getGameMetadata(game: game) else { return nil }
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
        guard signedIn else { throw NotSignedInError() }

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
