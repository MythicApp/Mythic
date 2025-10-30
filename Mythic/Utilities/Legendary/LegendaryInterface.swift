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

// MARK: - Legendary Class
/**
 Controls the function of the "legendary" cli, the backbone of the launcher's EGS capabilities.

 [Legendary GitHub Repository](https://github.com/derrod/legendary)
 */
final class Legendary {

    // MARK: - Properties

    static let configurationFolder: URL = Bundle.appHome!.appending(path: "Epic")
    /// The file location for legendary's configuration files.
    static let configLocation = configurationFolder.path // TODO: phase out of use

    /// Logger instance for legendary.
    static let log = Logger(subsystem: Logger.subsystem, category: "legendaryInterface")

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

    private static var legendaryExecutableURL: URL {
        URL(filePath: Bundle.main.path(forResource: "legendary/cli", ofType: nil)!)
    }

    private static func constructEnvironment(withAdditionalFlags environment: [String: String]?) -> [String: String] {
        var constructedEnvironment: [String: String] = .init()
        constructedEnvironment["LEGENDARY_CONFIG_PATH"] = configLocation
        constructedEnvironment.merge(environment ?? .init(), uniquingKeysWith: { $1 })
        return constructedEnvironment
    }

    @MainActor
    private static func applyOfflineFlagIfNeeded(_ args: [String]) -> [String] {
        var out = args
        if NetworkMonitor.shared.epicAccessibilityState != .accessible {
            out.append("--offline")
        }
        return out
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

    // Build Process.stream (no registration here; the consumer Task handles it)
    private static func startStream(
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        onChunk: (@Sendable (Process.OutputChunk) -> String?)? = nil
    ) -> AsyncThrowingStream<Process.OutputChunk, Error> {
        let env = constructEnvironment(withAdditionalFlags: environment)
        return Process.stream(
            executableURL: legendaryExecutableURL,
            arguments: arguments,
            environment: env,
            currentDirectoryURL: currentDirectoryURL,
            onChunk: onChunk
        )
    }

    // Create and REGISTER the consumer Task immediately; inside it, do the awaits and drain the stream.
    // This removes the need for pending cancels or session tokens.
    @discardableResult
    static func executeStreamed(
        identifier: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil,
        onChunk: @Sendable @escaping (Process.OutputChunk) -> String?
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
                // expected when cancelled via stop(id:)
            } catch {
                throw error
            }

            // clean up tracking after completion/cancellation/error
            await RunningCommands.shared.remove(id: identifier)
        }

        await RunningCommands.shared.set(id: identifier, task: consumer)
        return consumer
    }

    // MARK: - Install Method
    /**
     Installs, updates, or repairs games using legendary.
     */
    static func install(args: GameOperation.InstallArguments, priority: Bool = false) async throws {
        guard signedIn else { throw NotSignedInError() }
        guard case .epic = args.game.source else { throw IsNotLegendaryError() }

        var argBuilder = [
            "-y", "install",
            args.game.id,
            {
                switch args.type {
                case .install: return nil
                case .update:  return "--update-only"
                case .repair:  return "--repair"
                }
            }()
        ].compactMap { $0 }

        if case .install = args.type {
            switch args.platform {
            case .macOS:   argBuilder += ["--platform", "Mac"]
            case .windows: argBuilder += ["--platform", "Windows"]
            }

            if let baseURL = args.baseURL, files.fileExists(atPath: baseURL.path) {
                argBuilder += ["--base-path", baseURL.path(percentEncoded: false)]
            }

            if let gameFolder = args.gameFolder, files.fileExists(atPath: gameFolder.path) {
                argBuilder += ["--game-folder", gameFolder.absoluteString]
            }
        }

        let optionalPacks = args.optionalPacks
        let gameTitle = args.game.title

        // i dont like you swift 6
        final class ErrorBox: @unchecked Sendable {
            private let lock = NSLock()
            private var storage: Error?

            func set(_ error: Error) {
                lock.withLock {
                    storage = error
                }
            }

            func get() -> Error? {
                lock.withLock {
                    return storage
                }
            }
        }
        let errorBox = ErrorBox()

        let consumer = await executeStreamed(
            identifier: "install",
            arguments: argBuilder,
            onChunk: { chunk in
                // swiftlint:disable force_try
                let progressRegex: Regex = try! .init(#"Progress: (?<percentage>\d+\.\d+)% \((?<downloadedObjects>\d+)\/(?<totalObjects>\d+)\), Running for (?<runtime>\d+:\d+:\d+), ETA: (?<eta>\d+:\d+:\d+)"#)
                let downloadRegex: Regex = try! .init(#"Downloaded: (?<downloaded>\d+\.\d+) \w+, Written: (?<written>\d+\.\d+) \w+"#)
                let cacheRegex: Regex = try! .init(#"Cache usage: (?<usage>\d+\.\d+) \w+, active tasks: (?<activeTasks>\d+)"#)
                let downloadSpeedRegex: Regex = try! .init(#"\+ Download\s+- (?<raw>[\d.]+) \w+/\w+ \(raw\) / (?<decompressed>[\d.]+) \w+/\w+ \(decompressed\)"#)
                let diskSpeedRegex: Regex = try! .init(#"\+ Disk\s+- (?<write>[\d.]+) \w+/\w+ \(write\) / (?<read>[\d.]+) \w+/\w+ \(read\)"#)
                // swiftlint:enable force_try

                if chunk.output.contains("Additional packs") {
                    if let packs = optionalPacks, !packs.isEmpty {
                        return packs.joined(separator: ", ") + "\n"
                    } else {
                        return "\n"
                    }
                }

                if chunk.output.contains("All done! Download manager quitting...") {
                    Task {
                        await MainActor.run {
                            GameOperation.shared.current = nil
                        }
                    }
                }

                if let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: chunk.output),
                   let reasonSS = match.last?.substring {
                    errorBox.set(Legendary.InstallationError(errorDescription: String(reasonSS)))
                }

                if chunk.output.contains("Verification finished successfully.") {
                    Task { @MainActor in
                        let alert = NSAlert()

                        alert.messageText = String(localized: "Successfully verified \"\(gameTitle)\".")
                        alert.informativeText = String(localized: "\"\(gameTitle)\" is now ready to be played.")
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: String(localized: "OK"))

                        if let window = NSApp.windows.first { alert.beginSheetModal(for: window) }
                    }
                }

                if let match = try? progressRegex.firstMatch(in: chunk.output) {
                    Task { @MainActor in
                        GameOperation.shared.status.progress = GameOperation.InstallStatus.Progress(
                            percentage: Double(match["percentage"]?.substring.map(String.init) ?? "") ?? 0.0,
                            downloadedObjects: Int(match["downloadedObjects"]?.substring.map(String.init) ?? "") ?? 0,
                            totalObjects: Int(match["totalObjects"]?.substring.map(String.init) ?? "") ?? 0,
                            runtime: match["runtime"]?.substring.map(String.init) ?? "00:00:00",
                            eta: match["eta"]?.substring.map(String.init) ?? "00:00:00"
                        )
                    }
                }
                if let match = try? downloadRegex.firstMatch(in: chunk.output) {
                    Task { @MainActor in
                        GameOperation.shared.status.download = GameOperation.InstallStatus.Download(
                            downloaded: Double(match["downloaded"]?.substring.map(String.init) ?? "") ?? 0.0,
                            written: Double(match["written"]?.substring.map(String.init) ?? "") ?? 0.0
                        )
                    }
                }
                if let match = try? cacheRegex.firstMatch(in: chunk.output) {
                    Task { @MainActor in
                        GameOperation.shared.status.cache = GameOperation.InstallStatus.Cache(
                            usage: Double(match["usage"]?.substring.map(String.init) ?? "") ?? 0.0,
                            activeTasks: Int(match["activeTasks"]?.substring.map(String.init) ?? "") ?? 0
                        )
                    }
                }
                if let match = try? downloadSpeedRegex.firstMatch(in: chunk.output) {
                    Task { @MainActor in
                        GameOperation.shared.status.downloadSpeed = GameOperation.InstallStatus.DownloadSpeed(
                            raw: Double(match["raw"]?.substring.map(String.init) ?? "") ?? 0.0,
                            decompressed: Double(match["decompressed"]?.substring.map(String.init) ?? "") ?? 0.0
                        )
                    }
                }
                if let match = try? diskSpeedRegex.firstMatch(in: chunk.output) {
                    Task { @MainActor in
                        GameOperation.shared.status.diskSpeed = GameOperation.InstallStatus.DiskSpeed(
                            write: Double(match["write"]?.substring.map(String.init) ?? "") ?? 0.0,
                            read: Double(match["read"]?.substring.map(String.init) ?? "") ?? 0.0
                        )
                    }
                }

                return nil
            }
        )

        // Wait for streaming to finish
        try await consumer.value

        if let err = errorBox.get() {
            throw err
        }
    }

    static func move(game: Mythic.Game, newPath: String) async throws {
        if let oldPath = try getGamePath(game: game) {
            guard files.isWritableFile(atPath: oldPath) else { throw CocoaError(.fileWriteUnknown) }
            try files.moveItem(atPath: oldPath, toPath: "\(newPath)/\(oldPath.components(separatedBy: "/").last!)")

            _ = try await execute(arguments: ["move", game.id, newPath, "--skip-move"])

            try await notifications.add(
                .init(identifier: UUID().uuidString,
                      content: {
                          let content = UNMutableNotificationContent()
                          content.title = String(localized: "Finished moving \"\(game.title)\".")
                          content.body = String(localized: "\"\(game.title)\" can now be found at \(URL(filePath: newPath).prettyPath())")
                          return content
                      }(),
                      trigger: nil)
            )
        }
    }

    @discardableResult
    static func signIn(authKey: String) async throws -> String {
        let result = try await execute(arguments: ["auth", "--code", authKey])
        // Legendary prints login success to stderr
        if let match = try? Regex(#"Successfully logged in as \"(?<username>[^\"]+)\""#).firstMatch(in: result.standardError),
           let usernameSS = match["username"]?.substring {
            await GameListVM.shared.refresh()
            return String(usernameSS)
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
    static func launch(game: Mythic.Game) async throws {
        guard try Legendary.getInstalledGames().contains(game) else {
            log.error("Unable to launch game, not installed or missing")
            throw GameDoesNotExistError(game)
        }

        if game.needsVerification, let platform = game.platform {
            GameOperation.shared.queue.append(
                GameOperation.InstallArguments(
                    game: game,
                    platform: platform,
                    type: .repair
                )
            )

            // FIXME: notify the user lol
            return // allow the game to repair first!!
        }

        if game.platform == .windows, !Engine.isInstalled {
            throw Engine.NotInstalledError()
        }

        await MainActor.run {
            withAnimation {
                GameOperation.shared.launching = game
            }
        }

        try defaults.encodeAndSet(game, forKey: "recentlyPlayed")

        var arguments = [
            "launch",
            game.id,
            needsUpdate(game: game) ? "--skip-version-check" : nil
        ].compactMap { $0 }

        var environmentVariables: [String: String] = .init()

        if case .windows = game.platform {
            guard let containerURL = game.containerURL else { throw Wine.ContainerDoesNotExistError() } // FIXME: Container Revamp
            let container = try Wine.getContainerObject(url: containerURL)

            arguments += ["--wine", Engine.directory.appending(path: "wine/bin/wine64").path]
            // required for launching w/ legendary
            environmentVariables["WINEPREFIX"] = container.url.path(percentEncoded: false)

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
        }

        arguments.append(contentsOf: ["--"] + game.launchArguments)

        // launch game; fire and forget
        Task(priority: .userInitiated) {
            _ = try await execute(
                arguments: arguments,
                environment: environmentVariables
            )
        }
    }

    // MARK: Get Game Platform Method

    static func getGamePlatform(game: Mythic.Game) throws -> Mythic.Game.Platform? {
        guard case .epic = game.source else {
            throw IsNotLegendaryError()
        }

        let installedData = URL(filePath: "\(configLocation)/installed.json")
        let data = try Data(contentsOf: installedData)

        guard let installedGames = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard let platformString = installedGames[game.id]?["platform"] as? String else {
            throw UnableToRetrieveError()
        }

        return matchPlatform(for: platformString)
    }

    // MARK: Needs Update Method

    static func needsUpdate(game: Mythic.Game) -> Bool {
        do {
            let metadata = try getGameMetadata(game: game)
            let installedJSON = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))

            guard
                let installedVersion = installedJSON[game.id]["version"].string,
                let platform = installedJSON[game.id]["platform"].string,
                let upstreamVersion = metadata?["asset_infos"][platform]["build_version"].string
            else {
                log.error("Unable to compare versions for game \"\(game.title)\".")
                return false
            }

            return upstreamVersion != installedVersion
        } catch {
            log.error("Error checking if \(game.title) needs an update: \(error.localizedDescription)")
            return false
        }
    }

    static func needsVerification(game: Mythic.Game) -> Bool {
        do {
            let installedJSON = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))
            return installedJSON[game.id]["needs_verification"].boolValue
        } catch {
            log.error("Error checking if \(game.title) needs verification: \(error.localizedDescription)")
            return false
        }
    }

    /// Queries for the user that is currently signed into epic games.
    static var user: String? {
        let json: URL = .init(filePath: "\(configLocation)/user.json")
        guard let json = try? JSON(data: .init(contentsOf: json)) else {
            return nil
        }
        return String(describing: json["displayName"])
    }

    /// Checks account signin state.
    static var signedIn: Bool { return user != nil }

    // MARK: - Get Installed Games Method

    static func getInstalledGames() throws -> [Mythic.Game] {
        guard signedIn else { throw NotSignedInError() }

        let installedData = URL(filePath: "\(configLocation)/installed.json")
        let data = try Data(contentsOf: installedData)

        guard let installedGames = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileNoSuchFile)
        }

        return installedGames.compactMap { (id, gameInfo) -> Mythic.Game? in
            guard let title = gameInfo["title"] as? String,
                  let platformString = gameInfo["platform"] as? String,
                  let platform: Mythic.Game.Platform = matchPlatform(for: platformString),
                  let installPath = gameInfo["install_path"] as? String else {
                return nil
            }

            return .init(source: .epic, title: title, id: id, platform: platform, path: installPath)
        }
    }

    static func getGamePath(game: Mythic.Game) throws -> String? {
        guard signedIn else { throw NotSignedInError() }
        guard case .epic = game.source else { throw IsNotLegendaryError() }

        let installed = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))
        return installed[game.id]["install_path"].string
    }

    // MARK: - Get Installable Method

    static func getInstallable() throws -> [Mythic.Game] {
        guard signedIn else { throw NotSignedInError() }

        let metadata = "\(configLocation)/metadata"

        let games = try files.contentsOfDirectory(atPath: metadata).map { file -> Mythic.Game in
            let json = try JSON(data: .init(contentsOf: .init(filePath: "\(metadata)/\(file)")))
            return .init(source: .epic, title: json["app_title"].stringValue, id: json["app_name"].stringValue, platform: .macOS, path: "")
        }

        return games.sorted { $0.title < $1.title }
    }

    // MARK: - Get Game Metadata Method

    static func getGameMetadata(game: Mythic.Game) throws -> JSON? {
        guard case .epic = game.source else { throw IsNotLegendaryError() }
        let metadataDirectoryString = "\(configLocation)/metadata"

        guard let metadataDirectoryContents = try? files.contentsOfDirectory(atPath: metadataDirectoryString) else {
            throw CocoaError(.fileNoSuchFile)
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
     Retrieve a game's launch arguments from Legendary's `installed.json` file.
     ** This isn't compatible with Mythic'c current launch argument implementation, and likely will remain in this unimplemented state.
     */
    static func getGameLaunchArguments(game: Mythic.Game) throws -> [String] {
        let installedData = try JSON(data: Data(contentsOf: URL(filePath: "\(configLocation)/installed.json")))
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

    static func getImageMetadata(for game: Mythic.Game, type: ImageType) -> JSON? {
        let metadata = try? getGameMetadata(game: game)
        let keyImages = metadata?["metadata"]["keyImages"].array ?? .init()

        let prioritisedTypes: [String] = {
            switch type {
            case .normal: return ["DieselGameBoxWide", "DieselGameBox"]
            case .tall: return ["DieselGameBoxTall"]
            }
        }()

        return keyImages.first(where: { prioritisedTypes.contains($0["type"].stringValue) })
    }

    static func matchPlatform(for string: String) -> Game.Platform? {
        switch string {
        case "Windows":
            return .windows
        case "Mac":
            return .macOS
        default:
            return nil
        }
    }

    /**
     Retrieves game thumbnail image from legendary's downloaded metadata.
     */
    static func getImage(of game: Mythic.Game, type: ImageType) -> String {
        let imageMetadata = getImageMetadata(for: game, type: type)

        if let imageURL = imageMetadata?["url"].stringValue {
            return imageURL
        }

        let metadata = try? getGameMetadata(game: game)
        let keyImages = metadata?["metadata"]["keyImages"].array ?? .init()

        // fallback #1
        if let fallbackURL = keyImages.first(where: {
            guard let width = $0["width"].int, let height = $0["height"].int else { return false }
            return (type == .normal && width >= height) || (type == .tall && height > width)
        })?["url"].stringValue {
            return fallbackURL
        }

        // fallback #2
        return keyImages.first?["url"].stringValue ?? .init()
    }

    // MARK: - Is Alias Method

    static func isAlias(game: String) throws -> (Bool?, of: String?) {
        guard signedIn else { throw NotSignedInError() }

        let aliasesJSONFileURL: URL = URL(filePath: "\(configLocation)/aliases.json")

        guard let aliasesData = try? Data(contentsOf: aliasesJSONFileURL) else {
            throw CocoaError(.fileNoSuchFile)
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
