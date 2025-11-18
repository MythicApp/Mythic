//
//  LegendaryInterface.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 21/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import SwiftyJSON
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
                        qos: QualityOfService,
                        optionalPacks: [String] = .init(),
                        gameDirectoryURL: URL? = Bundle.appGames) async throws {
        var arguments: [String] = ["-y", "install", game.id]
        arguments += ["--platform", Legendary.matchPlatform(for: game.platform)]

        guard let gameDirectoryURL = gameDirectoryURL else {
            log.error("Failed to infer default base URL, installation cannot continue")
            throw CocoaError(.fileReadUnknown)
        }
        arguments += ["--game-folder", gameDirectoryURL.path]

        let operation: GameOperation = .init(game: game, type: .updating) { [arguments] progress in
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

        let operation: GameOperation = .init(game: game, type: .updating) { progress in
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

        let operation: GameOperation = .init(game: game, type: .launching) { progress in
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
        let gameID = game.id

        let operation: GameOperation = .init(game: game, type: .launching) { _ in
            var arguments: [String] = ["-y", "uninstall", gameID]

            if persistFiles { arguments += ["--keep-files"] }
            if !runUninstallerIfPossible { arguments += ["--skip-uninstaller"] }

            // legendary is inconsistent with this,
            // may have to use files.removeItem(atPath:)
            try await Legendary.execute(arguments: arguments)
        }

        await Game.operationManager.queueOperation(operation)
    }

    @MainActor static func move(game: EpicGamesGame, to newLocation: URL) async throws {
        let gameIsInstalled = game.isInstalled
        let currentGameLocation = game.location
        let gameID = game.id

        let operation: GameOperation = .init(game: game, type: .launching) { _ in
            guard gameIsInstalled,
                  let currentGameLocation = currentGameLocation else { throw CocoaError(.fileNoSuchFile) }

            try files.moveItem(at: currentGameLocation, to: newLocation)

            try await Legendary.execute(arguments: ["move", gameID, newLocation.path, "--skip-move"])
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
        guard game.isInstalled else { throw CocoaError(.fileNoSuchFile) }

        let gameContainerURL = game.containerURL
        let gameID = game.id
        let gameNeedsVerification = game.needsVerification
        let gamePlatform = game.platform
        let gameLaunchArguments = game.launchArguments

        let operation: GameOperation = .init(game: game, type: .launching) { progress in
            guard let containerURL = gameContainerURL else { throw Wine.Container.DoesNotExistError() }

            var arguments: [String] = ["launch", gameID]
            var environment: [String: String] = .init()

            guard !gameNeedsVerification else { throw EpicGamesGame.VerificationRequiredError() }

            // uses legendary's native launch process
            switch gamePlatform {
            case .macOS:
                do {} //
            case .windows:
                environment = try Wine.assembleEnvironmentVariables(forContainer: containerURL)
                // legendary requires this, since it calls wine directly.
                environment["WINEPREFIX"] = containerURL.path(percentEncoded: false)

                arguments += ["--wine", Engine.wineExecutableURL.path]
            }

            arguments.append(contentsOf: ["--"] + gameLaunchArguments)

            try await Legendary.execute(arguments: arguments,
                                        environment: environment)
        }

        Game.operationManager.queueOperation(operation)
    }

    // MARK: Get Game Platform Method

    static func getGamePlatform(game: EpicGamesGame) throws -> EpicGamesGame.Platform? {
        let installedData: URL = configurationFolder.appending(path: "installed.json")
        let data: Data = try .init(contentsOf: installedData)

        guard let installedGames = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard let platformString = installedGames[game.id]?["platform"] as? String else {
            throw UnableToRetrieveError()
        }

        return matchPlatformString(for: platformString)
    }

    static func fetchUpdateAvailability(for game: EpicGamesGame) async throws -> Bool {
        let metadata = try Legendary.getGameMetadata(game: game)

        let installedJSONURL: URL = Legendary.configurationFolder.appending(path: "installed.json")
        let installedJSONData: Data = try .init(contentsOf: installedJSONURL)
        let installedJSON = try JSON(data: installedJSONData)

        guard
            let installedVersion = installedJSON[game.id]["version"].string,
            let platform = installedJSON[game.id]["platform"].string,
            let upstreamVersion = metadata?["asset_infos"][platform]["build_version"].string
        else {
            throw CocoaError(.coderValueNotFound)
        }

        // it would be more ideal checking if upstreamVersion is greater than
        // installedVersion, but to do that, we'd need to convert them into
        // SemanticVersion, which is problematic because we have no guarantee
        // that the game uses semantic versioning.
        return upstreamVersion != installedVersion
    }

    static func isFileVerificationRequired(for game: EpicGamesGame) async throws -> Bool {
        let installedJSONURL: URL = Legendary.configurationFolder.appending(path: "installed.json")
        let installedJSONData: Data = try .init(contentsOf: installedJSONURL)
        let installedJSON = try JSON(data: installedJSONData)

        return installedJSON[game.id]["needs_verification"].boolValue
    }

    /// Queries for the user that is currently signed into epic games.
    static var user: String? {
        let json: URL = configurationFolder.appending(path: "user.json")
        guard let json = try? JSON(data: .init(contentsOf: json)) else {
            return nil
        }
        return String(describing: json["displayName"])
    }

    /// Checks account signin state.
    static var signedIn: Bool { return user != nil }

    static func getInstalledGames() throws -> [EpicGamesGame] {
        guard signedIn else { throw NotSignedInError() }

        let installedData = configurationFolder.appending(path: "installed.json")
        let data = try Data(contentsOf: installedData)

        guard let installedGames = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileNoSuchFile)
        }

        return installedGames.compactMap { (id, gameInfo) -> EpicGamesGame? in
            guard let title = gameInfo["title"] as? String,
                  let platformString = gameInfo["platform"] as? String,
                  let platform: Game.Platform = matchPlatformString(for: platformString),
                  let installPath = gameInfo["install_path"] as? String else {
                return nil
            }

            return .init(id: id,
                         title: title,
                         platform: platform,
                         location: .init(filePath: installPath))
        }
    }

    static func getGamePath(game: EpicGamesGame) throws -> String? {
        guard signedIn else { throw NotSignedInError() }

        let installed = try JSON(data: Data(contentsOf: configurationFolder.appending(path: "installed.json")))
        return installed[game.id]["install_path"].string
    }

    static func getInstallable() throws -> [EpicGamesGame] {
        guard signedIn else { throw NotSignedInError() }

        let metadataDirectory: URL = configurationFolder.appending(path: "metadata")

        let games = try files.contentsOfDirectory(atPath: metadataDirectory.path).map { fileName -> EpicGamesGame in
            let json = try JSON(data: .init(contentsOf: metadataDirectory.appending(path: fileName)))
            return .init(id: json["app_name"].stringValue,
                         title: json["app_title"].stringValue,
                         platform: .macOS, // FIXME: stub
                         location: nil)
        }

        return games.sorted { $0.title < $1.title }
    }

    static func getGameMetadata(game: EpicGamesGame) throws -> JSON? {
        let metadataDirectory: URL = configurationFolder.appending(path: "metadata")

        guard let metadataDirectoryContents = try? files.contentsOfDirectory(atPath: metadataDirectory.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        if let metadataFileName: String = metadataDirectoryContents.first(where: { $0.hasSuffix(".json") && $0.contains(game.id) }),
           let data: Data = try? .init(contentsOf: URL(filePath: metadataDirectory.appending(path: metadataFileName).path)),
           let json: JSON = try? .init(data: data) {
            return json
        }

        return nil
    }

    /**
     Retrieve a game's launch arguments from Legendary's `installed.json` file.
     ** This isn't compatible with Mythic'c current launch argument implementation, and likely will remain in this unimplemented state.
     */
    static func getGameLaunchArguments(game: EpicGamesGame) throws -> [String] {
        let installedData = try JSON(data: Data(contentsOf: configurationFolder.appending(path: "installed.json")))
        guard let arguments = installedData[game.id]["launch_parameters"].string else {
            throw UnableToRetrieveError()
        }
        return arguments.components(separatedBy: .whitespaces)
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

    static func getImageMetadata(for game: EpicGamesGame, type: ImageType) -> JSON? {
        guard let metadata = try? getGameMetadata(game: game),
              let keyImages = metadata["metadata"]["keyImages"].array else { return nil }

        let prioritisedTypes: [String] = {
            switch type {
            case .normal: return ["DieselGameBoxWide", "DieselGameBox"]
            case .tall: return ["DieselGameBoxTall"]
            }
        }()

        return keyImages.first(where: { prioritisedTypes.contains($0["type"].stringValue) })
    }

    static func matchPlatformString(for string: String) -> Game.Platform? {
        switch string {
        case "Windows": .windows
        case "Mac":     .macOS
        default:        nil
        }
    }

    static func matchPlatform(for platform: Game.Platform) -> String {
        switch platform {
        case .windows:  "Windows"
        case .macOS:    "Mac"
        }
    }

    /// Retrieves game thumbnail image from legendary's downloaded metadata.
    static func getImageURL(of game: EpicGamesGame, type: ImageType) -> String? {
        let imageMetadata = getImageMetadata(for: game, type: type)

        if let imageURL = imageMetadata?["url"].string {
            return imageURL
        }

        // fallback #1 — attempt to fetch best matching image for specified image type
        let metadata = try? getGameMetadata(game: game)
        let keyImages = metadata?["metadata"]["keyImages"].array ?? .init()

        if let bestImageMetadata = keyImages.first(where: {
            guard let width = $0["width"].int, let height = $0["height"].int else { return false }
            return (type == .normal && width >= height) || (type == .tall && height > width)
        }) {
            return bestImageMetadata["url"].string
        }

        // fallback #2 — use any available image
        return keyImages.first?["url"].string
    }

    // don't use or at least refactor 💔 i could not code back in 2023
    static func isAlias(game: String) throws -> (Bool?, of: String?) {
        guard signedIn else { throw NotSignedInError() }

        let aliasesFile: URL = configurationFolder.appending(path: "aliases.json")

        let aliasesData = try Data(contentsOf: aliasesFile)

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
