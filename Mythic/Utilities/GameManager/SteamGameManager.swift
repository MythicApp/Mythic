//
//  SteamGameManager.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import AppKit
import OSLog
import os

extension SteamGameManager: StorefrontGameManager {
    // Each witness forwards to a typed overload whose argument labels *differ* from its own. That is
    // deliberate: `EpicGamesGameManager.install(game:qualityOfService:)` called a typed overload sharing
    // its labels, re-selected itself, and recursed until the stack died.

    @MainActor static func launch(game: Game) async throws -> GameOperation {
        try await launch(steamGame: cast(game))
    }

    @MainActor static func move(game: Game, to newLocation: URL) async throws -> GameOperation {
        try await move(steamGame: cast(game), toLocation: newLocation)
    }

    @MainActor static func uninstall(game: Game, persistFiles: Bool) async throws -> GameOperation {
        try await uninstall(steamGame: cast(game), persistingFiles: persistFiles)
    }

    static func install(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        try await install(steamGame: cast(game), atQualityOfService: qualityOfService)
    }

    static func update(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        try await update(steamGame: cast(game), atQualityOfService: qualityOfService)
    }

    static func repair(game: Game, qualityOfService: QualityOfService) async throws -> GameOperation {
        try await repair(steamGame: cast(game), atQualityOfService: qualityOfService)
    }

    static func fetchUpdateAvailability(for game: Game) throws -> Bool {
        try fetchUpdateAvailability(forSteamGame: cast(game))
    }

    static func isFileVerificationRequired(for game: Game) throws -> Bool {
        try isFileVerificationRequired(forSteamGame: cast(game))
    }

    @MainActor static func importGame(_ game: Game, platform: Game.Platform, at location: URL) async throws {
        try await importSteamGame(cast(game), platform: platform, at: location)
    }

    private static func cast(_ game: Game) throws -> SteamGame {
        guard case .steam = game.storefront, let steamGame = game as? SteamGame else {
            throw CocoaError(.coderInvalidValue)
        }
        return steamGame
    }
}

final class SteamGameManager {
    static var log: Logger { .custom(category: "SteamGameManager") }

    struct NoLaunchOptionError: LocalizedError {
        let title: String
        var errorDescription: String? {
            String(localized: "Steam doesn't list a way to launch \(title) on this platform.")
        }
    }

    struct NotInstalledError: LocalizedError {
        var errorDescription: String? = String(localized: "That game isn't installed.")
    }

    /**
     A game that started and then exited straight away.

     Reported because the alternative is worse: the launch operation completed without error, so the UI
     showed a brief spinner and then nothing at all, with no way for anyone to find out why. The most
     common cause for a Steam title is Steamworks failing to initialise, which needs the Steam client --
     so whether the container even has one is checked and said out loud.
     */
    struct ImmediateExitError: LocalizedError {
        let title: String
        let isSteamClientMissing: Bool
        /// Tail of the process's own output, for the log rather than the alert.
        let output: String

        var errorDescription: String? {
            isSteamClientMissing
                ? String(localized: """
                    \(title) closed immediately.
                    Titles that use Steamworks need the Steam client installed in their container, and this one hasn't got it.
                    """)
                : String(localized: "\(title) closed immediately after starting.")
        }

        var failureReason: String? { output.isEmpty ? nil : output }
    }

    /// A launch that ends sooner than this is treated as a failure to start rather than a short session.
    private static let immediateExitThreshold: TimeInterval = 15

    // MARK: - Acquisition
    //
    // Board items: "Game installing + progress handling", "Game update checker".

    @discardableResult
    static func install(steamGame game: SteamGame,
                        atQualityOfService qualityOfService: QualityOfService) async throws -> GameOperation {
        try await runContentOperation(on: game,
                                      type: .install,
                                      validate: false,
                                      qualityOfService: qualityOfService)
    }

    @discardableResult
    static func update(steamGame game: SteamGame,
                       atQualityOfService qualityOfService: QualityOfService) async throws -> GameOperation {
        try await runContentOperation(on: game,
                                      type: .update,
                                      validate: false,
                                      qualityOfService: qualityOfService)
    }

    /// Steam has no distinct repair verb; `app_update ... validate` re-hashes and refetches what differs.
    @discardableResult
    static func repair(steamGame game: SteamGame,
                       atQualityOfService qualityOfService: QualityOfService) async throws -> GameOperation {
        try await runContentOperation(on: game,
                                      type: .repair,
                                      validate: true,
                                      qualityOfService: qualityOfService)
    }

    private static func runContentOperation(on game: SteamGame,
                                            type: GameOperation.ActiveOperationType,
                                            validate: Bool,
                                            qualityOfService: QualityOfService) async throws -> GameOperation {
        guard SteamCMD.isInstalled else { throw SteamCMD.Failure.notInstalled }
        guard Steam.isSignedIn else { throw Steam.NotSignedInError() }

        let appID = game.appID
        let installURL = Steam.installURL(forAppID: appID)
        let platform: Game.Platform = Steam.forcedPlatform == .macos ? .macOS : .windows

        let operation: GameOperation = .init(game: game, type: type) { progress in
            progress.totalUnitCount = 100
            progress.fileOperationKind = .downloading

            let rate: DownloadRateEstimator = .init()

            try await SteamCMD.run(
                commands: [.appUpdate(appID: appID, validate: validate)],
                installDirectory: installURL,
                // cachedAccountName, not retrieveUser(): the latter can return a display-only
                // placeholder, and `+login <placeholder>` fails.
                credentials: .init(username: Steam.cachedAccountName ?? "anonymous"),
                forcedPlatform: Steam.forcedPlatform
            ) { line in
                apply(line, to: progress, rate: rate)
            }

            // Only trust the manifest Steam actually wrote, not the fact that the process exited 0.
            guard FileManager.default.fileExists(
                atPath: installURL.appending(path: "steamapps/appmanifest_\(appID).acf").path(percentEncoded: false)
            ) else {
                throw SteamCMD.Failure.appOperationFailed(appID: appID, reason: "no app manifest was written")
            }

            game.installationState = .installed(location: installURL, platform: platform)

            // Cache the launch metadata now, while we are already online, so launching is not the first
            // thing that ever needs it.
            try? await Steam.refreshAppInfo(appID: appID)
        }

        operation.qualityOfService = qualityOfService
        await Game.operationManager.queueOperation(operation)
        return operation
    }

    /**
     Maps SteamCMD's progress line onto `Progress`.

     Byte counts deliberately do *not* go into `fileTotalCount`/`fileCompletedCount`. Those are item
     counts -- the status sheet renders them under a "Files" label as `(x/y)` -- so a 41 GB download
     reported as `Files (81280707/41306371057)` is not information, it is noise. Epic has real object
     counts there; Steam has none, and the sheet now hides the row rather than showing `(0/0)`.

     SteamCMD reports neither throughput nor an ETA, but both follow from consecutive readings of the
     cumulative byte count, so they are derived rather than left blank. The rate is smoothed, because a
     raw two-second delta jitters enough to be unreadable.
     */
    private static func apply(_ line: SteamCMDOutput.Line,
                              to progress: Progress,
                              rate: DownloadRateEstimator) {
        guard case .progress(let update) = line else { return }

        progress.completedUnitCount = Int64(update.percentage.rounded())
        progress.fileOperationKind = update.phase.isDownloading ? .downloading : .copying

        guard update.totalBytes > 0,
              let estimate = rate.sample(currentBytes: update.currentBytes,
                                         totalBytes: update.totalBytes)
        else { return }

        progress.throughput = estimate.bytesPerSecond
        progress.estimatedTimeRemaining = estimate.timeRemaining
    }

    /// Derives download rate and time remaining from SteamCMD's cumulative byte counter.
    fileprivate final class DownloadRateEstimator: Sendable {
        /// Weight of each new reading. Low enough that one slow tick does not swing the displayed rate.
        private static let smoothingFactor: Double = 0.3

        private let state: OSAllocatedUnfairLock<Sample> = .init(initialState: .init())

        func sample(currentBytes: Int64, totalBytes: Int64) -> (bytesPerSecond: Int, timeRemaining: TimeInterval)? {
            state.withLock { state in
                let now: Date = .now
                defer { state.bytes = currentBytes; state.takenAt = now }

                guard let previousBytes = state.bytes, let takenAt = state.takenAt else { return nil }

                let elapsed = now.timeIntervalSince(takenAt)
                // SteamCMD reprints progress often; ignore samples too close together to measure a rate
                // from, and ignore the counter resetting between phases.
                guard elapsed >= 0.5, currentBytes >= previousBytes else { return nil }

                let instantaneous = Double(currentBytes - previousBytes) / elapsed
                let rate = state.smoothedRate
                    .map { $0 + Self.smoothingFactor * (instantaneous - $0) } ?? instantaneous
                state.smoothedRate = rate

                guard rate > 0 else { return nil }

                return (bytesPerSecond: Int(rate),
                        timeRemaining: Double(max(0, totalBytes - currentBytes)) / rate)
            }
        }
    }

    /// Whether the container has a Steam client executable for Steamworks titles to talk to.
    private static func containerHasSteamClient(at containerURL: URL) -> Bool {
        let steamDirectory = containerURL.appending(path: "drive_c/Program Files (x86)/Steam")

        return ["steam.exe", "Steam.exe"].contains {
            FileManager.default.fileExists(
                atPath: steamDirectory.appending(path: $0).path(percentEncoded: false)
            )
        }
    }

    /// Keeps the tail of a launched process's output, so a failure to start can explain itself.
    private final class LaunchDiagnostics: Sendable {
        private static let limit: Int = 40

        private let lines: OSAllocatedUnfairLock<[String]> = .init(initialState: .init())

        func record(_ line: String) {
            lines.withLock { lines in
                lines.append(line)
                if lines.count > Self.limit { lines.removeFirst(lines.count - Self.limit) }
            }
        }

        var tail: String {
            lines.withLock { $0.joined(separator: "\n") }
        }
    }

    // MARK: - State
    //
    // Both of these are synchronous by protocol, so they read the on-disk manifest rather than asking
    // SteamCMD -- `app_status` would work but is async and cannot be reached from here.

    static func fetchUpdateAvailability(forSteamGame game: SteamGame) throws -> Bool {
        guard let manifest = game.appManifest else { throw NotInstalledError() }
        return manifest.isUpdateAvailable
    }

    static func isFileVerificationRequired(forSteamGame game: SteamGame) throws -> Bool {
        guard let manifest = game.appManifest else { throw NotInstalledError() }
        return manifest.requiresVerification
    }

    // MARK: - Moving
    //
    // Board item: "Game moving".

    @discardableResult
    @MainActor static func move(steamGame game: SteamGame, toLocation newLocation: URL) async throws -> GameOperation {
        guard case .installed(let currentLocation, let platform) = game.installationState else {
            throw NotInstalledError()
        }

        let operation: GameOperation = .init(game: game, type: .move) { _ in
            try FileManager.default.moveItem(at: currentLocation, to: newLocation)
            game.installationState = .installed(location: newLocation, platform: platform)
        }

        await Game.operationManager.queueOperation(operation)
        return operation
    }

    // MARK: - Uninstalling

    @discardableResult
    @MainActor static func uninstall(steamGame game: SteamGame, persistingFiles: Bool) async throws -> GameOperation {
        guard case .installed(let location, _) = game.installationState else { throw NotInstalledError() }

        let operation: GameOperation = .init(game: game, type: .uninstall) { _ in
            if !persistingFiles {
                // Deleting the directory is the uninstall: `app_uninstall` only works against a library
                // Steam itself manages, and Mythic gives every title its own force_install_dir.
                try FileManager.default.removeItemIfExists(at: location)
            }

            game.installationState = .uninstalled
        }

        await Game.operationManager.queueOperation(operation)
        return operation
    }

    // MARK: - Importing

    @MainActor static func importSteamGame(_ game: SteamGame,
                                           platform: Game.Platform,
                                           at location: URL) async throws {
        guard (try? ValveDataFormat.parseAppManifest(
            contentsOf: location.appending(path: "steamapps/appmanifest_\(game.appID).acf")
        )) != nil else {
            throw SteamCMD.Failure.appOperationFailed(
                appID: game.appID,
                reason: "no Steam app manifest for this appid at that location"
            )
        }

        game.installationState = .installed(location: location, platform: platform)
        GameDataStore.shared.library.update(with: game)
    }

    // MARK: - Launching

    @discardableResult
    @MainActor static func launch(steamGame game: SteamGame) async throws -> GameOperation {
        guard case .installed(let location, let platform) = game.installationState else {
            throw NotInstalledError()
        }

        let appID = game.appID
        let title = game.title

        let operation: GameOperation = .init(game: game, type: .launch) { _ in
            let info = try await Steam.appInfo(appID: appID)
            let operatingSystem = platform == .macOS ? "macos" : "windows"

            guard let option = info.preferredLaunchOption(forOperatingSystem: operatingSystem) else {
                throw NoLaunchOptionError(title: title)
            }

            // Steam's `executable` is relative to the install directory.
            let executableURL = location.appending(path: option.executable)
            guard FileManager.default.fileExists(atPath: executableURL.path(percentEncoded: false)) else {
                throw CocoaError(.fileNoSuchFile)
            }

            // Steam's own option arguments come first, then anything the user added in Mythic.
            let arguments = (option.arguments?
                .split(separator: " ")
                .map(String.init) ?? .init()) + game.launchArguments

            switch platform {
            case .macOS:
                let configuration: NSWorkspace.OpenConfiguration = .init()
                configuration.arguments = arguments
                _ = try await NSWorkspace.shared.openApplication(at: executableURL, configuration: configuration)

            case .windows:
                guard let containerURL = game.containerURL else { throw Wine.Container.DoesNotExistError() }
                let container = try Wine.getContainerObject(at: containerURL)

                if UserDefaults.standard.bool(forKey: "minimiseOnGameLaunch") {
                    await MainActor.run { NSApp.windows.first?.miniaturize(nil) }
                }

                let process: Process = .init()
                process.arguments = [executableURL.path] + arguments
                // Games resolve their own data relative to the working directory; Steam sets it to the
                // install directory and so must we.
                process.currentDirectoryURL = location
                // Environment first: `transformProcess` replaces `process.environment` wholesale.
                process.environment = try Wine.assembleEnvironmentVariables(forContainerAtURL: container.url)
                Wine.transformProcess(process, containerURL: containerURL)

                let diagnostics: LaunchDiagnostics = .init()
                let startedAt: Date = .now

                try await withTaskCancellationHandler {
                    // Streamed rather than fire-and-forget: when a game fails to start it explains itself
                    // on stderr, and that explanation was previously discarded.
                    try await process.runStreamed(throwsOnChunkError: false) { chunk in
                        diagnostics.record(chunk.output)
                        return nil
                    }
                } onCancel: {
                    process.interrupt()
                }

                guard Date.now.timeIntervalSince(startedAt) >= immediateExitThreshold else {
                    throw ImmediateExitError(
                        title: title,
                        isSteamClientMissing: !containerHasSteamClient(at: containerURL),
                        output: diagnostics.tail
                    )
                }
            }
        }

        await Game.operationManager.queueOperation(operation)
        return operation
    }
}

extension SteamGameManager.DownloadRateEstimator {
    struct Sample: Sendable {
        var bytes: Int64?
        var takenAt: Date?
        var smoothedRate: Double?
    }
}
