//
//  SteamCMD.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

// Reference: https://developer.valvesoftware.com/wiki/SteamCMD (403s to non-browser clients)

import Foundation
import OSLog
import os

/**
 Mythic's SteamCMD backend.

 SteamCMD is Valve's headless content client. It is a **native macOS binary** and never involves Wine,
 which is what makes the Steam acquisition path viable on the current engine even though the Steam GUI
 client is not — see ``SteamGame`` for that ceiling.
 */
final class SteamCMD {
    static let log: Logger = .custom(category: "steamcmd")

    // MARK: - Locations

    /// `~/Library/Application Support/Mythic/Steam`
    static var directory: URL {
        Bundle.appHome!.appending(path: "Steam")
    }

    /**
     `HOME` handed to every SteamCMD invocation.

     SteamCMD writes its session, caches and logs relative to `HOME` — by default straight into
     `~/Library/Application Support/Steam`, i.e. into a native Steam client's installation, where it can
     disturb an existing login. Pointing `HOME` here keeps Mythic's copy entirely to itself.

     Verified: with `HOME` scoped, a full `login anonymous` run wrote 15 files under this directory and
     touched **nothing** in the user's real Steam install.
     */
    static var homeDirectory: URL {
        directory.appending(path: "root")
    }

    /**
     The wrapper script, never the raw `steamcmd` binary.

     `steamcmd.sh` exports `DYLD_LIBRARY_PATH`/`DYLD_FRAMEWORK_PATH` pointing at its own directory, and
     re-execs itself on exit code 42 — which *is* the self-update mechanism. Invoking the binary directly
     loses both.
     */
    static var executableURL: URL {
        directory.appending(path: "steamcmd.sh")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: executableURL.path(percentEncoded: false))
    }

    // MARK: - Failures

    enum Failure: LocalizedError, Equatable {
        case rosettaMissing
        case notInstalled
        case bootstrapFailed(underlying: String)
        case loginFailed(detail: String?)
        case invalidCredentials
        case twoFactorRequired
        case rateLimited
        case mobileConfirmationTimedOut
        case loginDidNotComplete
        case appOperationFailed(appID: String, reason: String)

        var errorDescription: String? {
            switch self {
            case .rosettaMissing:
                String(localized: "SteamCMD is an Intel binary and needs Rosetta 2 to run.")
            case .notInstalled:
                String(localized: "SteamCMD isn't installed yet.")
            case .bootstrapFailed(let underlying):
                String(localized: "Couldn't install SteamCMD: \(underlying)")
            case .loginFailed(let detail):
                detail.map { String(localized: "Steam sign-in failed: \($0)") }
                    ?? String(localized: "Steam sign-in failed.")
            case .invalidCredentials:
                String(localized: "That Steam username or password wasn't accepted.")
            case .twoFactorRequired:
                String(localized: "Steam needs a Steam Guard code to continue.")
            case .rateLimited:
                String(localized: "Steam is rate-limiting sign-in attempts. Wait a few minutes and try again.")
            case .mobileConfirmationTimedOut:
                String(localized: """
                    Steam was waiting for you to approve the sign-in in the Steam Mobile App, and gave up.
                    Try again, and confirm the request on your phone when it appears.
                    """)
            case .loginDidNotComplete:
                String(localized: "Steam ended the sign-in without accepting or rejecting it. Try again.")
            case .appOperationFailed(let appID, let reason):
                String(localized: "Steam couldn't complete the operation for app \(appID): \(reason)")
            }
        }
    }

    // MARK: - Bootstrap

    /// Downloads and unpacks SteamCMD into ``directory``.
    static func install() async throws {
        guard Rosetta.exists else { throw Failure.rosettaMissing }

        let fileManager: FileManager = .default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: homeDirectory, withIntermediateDirectories: true)

        let archiveURL = URL(string: "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz")!
        let (temporaryURL, response) = try await URLSession.shared.download(from: archiveURL)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw Failure.bootstrapFailed(underlying: "HTTP \(response.statusCode)")
        }

        let unarchive: Process = .init()
        unarchive.executableURL = .init(filePath: "/usr/bin/tar")
        unarchive.arguments = ["zxf", temporaryURL.path(percentEncoded: false),
                               "-C", directory.path(percentEncoded: false)]

        // `runWrapped` is overloaded sync/async and the compiler picks the async one here; name it
        // explicitly so the choice is visible rather than contextual.
        let result = try await unarchive.runWrappedAsync()
        try unarchive.checkTerminationStatus()

        guard isInstalled else {
            throw Failure.bootstrapFailed(underlying: result.standardError ?? "steamcmd.sh missing after unpack")
        }

        log.notice("SteamCMD installed at \(directory.path(percentEncoded: false), privacy: .public)")
    }

    static func uninstall() throws {
        try FileManager.default.removeItemIfExists(at: directory)
    }

    // MARK: - Invocation

    struct Credentials: Sendable {
        var username: String
        var password: String?
        /// Steam Guard email code or mobile authenticator code, if one is already known.
        var steamGuardCode: String?

        /// Anonymous access. Only content Valve publishes anonymously is reachable this way.
        static let anonymous = Credentials(username: "anonymous")
    }

    /// `@sSteamCmdForcePlatformType`. Windows is the default: it is what makes the catalogue large enough
    /// to be worth having, and Mythic runs those titles through Wine.
    enum ForcedPlatform: String, Sendable {
        case windows, macos, linux
    }

    enum Command: Sendable {
        case appUpdate(appID: String, validate: Bool)
        case appInfoPrint(appID: String)
        case appInfoUpdate
        case appStatus(appID: String)
        case licensesPrint
        case packageInfoPrint(packageID: String)
        case raw(String)

        var arguments: [String] {
            switch self {
            case .appUpdate(let appID, let validate):
                validate ? ["+app_update", appID, "validate"] : ["+app_update", appID]
            case .appInfoPrint(let appID):
                ["+app_info_print", appID]
            case .appInfoUpdate:
                ["+app_info_update", "1"]
            case .appStatus(let appID):
                ["+app_status", appID]
            case .licensesPrint:
                ["+licenses_print"]
            case .packageInfoPrint(let packageID):
                ["+package_info_print", packageID]
            case .raw(let command):
                ["+\(command)"]
            }
        }
    }

    /// Answers SteamCMD's stdin prompts, and refuses to answer the same one forever.
    private final class PromptResponder: Sendable {
        private let credentials: Credentials?
        private let answered: OSAllocatedUnfairLock<[SteamCMDOutput.Prompt: Int]> = .init(initialState: .init())

        init(credentials: Credentials?) {
            self.credentials = credentials
        }

        /// - Returns: the reply to write to stdin, or `nil` to stay silent.
        func reply(to prompt: SteamCMDOutput.Prompt) -> String? {
            answered.withLock { answered in
                // A wrong password makes SteamCMD re-prompt; answering identically forever would hang the
                // operation and burn through Steam's sign-in rate limit.
                let attempts = answered[prompt, default: 0]
                guard attempts < 1 else { return nil }
                answered[prompt] = attempts + 1

                return switch prompt {
                case .password:         credentials?.password.map { $0 + "\n" }
                case .steamGuardCode,
                     .twoFactorCode:    credentials?.steamGuardCode.map { $0 + "\n" }
                }
            }
        }

        func wasPrompted(for prompt: SteamCMDOutput.Prompt) -> Bool {
            answered.withLock { $0[prompt, default: 0] > 0 }
        }
    }

    /**
     Serialises SteamCMD invocations.

     Every run shares one session directory, and concurrent runs corrupt each other's output rather than
     failing cleanly. Measured: two overlapping enumerations of the same account returned 4 and 18 app IDs
     where one run returns 455 — each process saw a fragment of the other's `licenses_print`, and the
     second wrote its truncated result over the first's.

     Browsing during a long download stays responsive because metadata is read from the on-disk cache,
     not by starting a run.
     */
    private actor SessionGate {
        static let shared = SessionGate()

        private var isBusy = false
        private var waiters: [CheckedContinuation<Void, Never>] = .init()

        func acquire() async {
            guard isBusy else { isBusy = true; return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func release() {
            if waiters.isEmpty {
                isBusy = false
            } else {
                waiters.removeFirst().resume()
            }
        }
    }

    /**
     Runs SteamCMD and returns its complete output.

     Use this, not ``run(commands:...)``, whenever the output *is* the result — `licenses_print`,
     `package_info_print`, `app_info_print`. `Process.runStreamed` splits whatever a single `read()`
     returned and discards whether a newline terminated it, so a line spanning two reads arrives as two
     fragments that no line-oriented pattern can match. Measured: an enumeration that received 188 licence
     lines parsed 7 of them, because most arrived cut mid-line:

         License packageID 7:
          - State   :

     Streaming remains right for downloads, where progress matters more than any individual line, and for
     signing in, where prompts must be answered as they appear.
     */
    static func capture(
        commands: [Command],
        credentials: Credentials? = nil,
        forcedPlatform: ForcedPlatform? = nil,
        stopOnFailedCommand: Bool = false
    ) async throws -> String {
        guard isInstalled else { throw Failure.notInstalled }
        guard Rosetta.exists else { throw Failure.rosettaMissing }

        await SessionGate.shared.acquire()
        defer { Task { await SessionGate.shared.release() } }

        let process = try prepareProcess(commands: commands,
                                         installDirectory: nil,
                                         credentials: credentials,
                                         forcedPlatform: forcedPlatform,
                                         stopOnFailedCommand: stopOnFailedCommand)

        let result = try await process.runWrappedAsync()

        // Some of SteamCMD's own chatter goes to stderr; the caller wants the transcript, not the split.
        return [result.standardOutput, result.standardError].compactMap { $0 }.joined(separator: "\n")
    }

    /**
     Runs SteamCMD and reports every classified line.

     Argument order is assembled here rather than by callers because it is load-bearing:
     **`force_install_dir` must precede `login`**, otherwise SteamCMD refuses with
     `Please use force_install_dir before logon!`.

     - Note: `Process.runStreamed` splits whatever a single `read()` returned, so a line delivered across
       two reads arrives as two chunks. Prompts survive this because they are matched with `contains`;
       a progress tick split this way is simply missed, which is harmless.
     */
    @discardableResult
    static func run(
        commands: [Command],
        installDirectory: URL? = nil,
        credentials: Credentials? = nil,
        forcedPlatform: ForcedPlatform? = .windows,
        requiresSuccessfulLogin: Bool = false,
        stopOnFailedCommand: Bool = true,
        onLine: (@Sendable (SteamCMDOutput.Line) -> Void)? = nil
    ) async throws -> Process {
        guard isInstalled else { throw Failure.notInstalled }
        guard Rosetta.exists else { throw Failure.rosettaMissing }

        await SessionGate.shared.acquire()
        defer { Task { await SessionGate.shared.release() } }

        let process = try prepareProcess(commands: commands,
                                         installDirectory: installDirectory,
                                         credentials: credentials,
                                         forcedPlatform: forcedPlatform,
                                         stopOnFailedCommand: stopOnFailedCommand)

        let responder: PromptResponder = .init(credentials: credentials)
        let outcome: OperationOutcome = .init()

        // Cancellation is handled here rather than by callers: only this scope has the child process
        // while it is running. The previous arrangement handed the process back to the caller *after*
        // the await returned, so its cancellation handler had nothing to interrupt.
        try await withTaskCancellationHandler {
            try await process.runStreamed(throwsOnChunkError: false) { chunk in
            let line = SteamCMDOutput.classify(chunk.output)
            onLine?(line)

            switch line {
            case .prompt(let prompt):
                return responder.reply(to: prompt)
            case .failure(let failure):
                outcome.record(translate(failure))
            case .loginInProgress, .awaitingMobileConfirmation:
                // SteamCMD interleaves diagnostics mid-line, so a verdict can arrive as its own chunk --
                // observed with `Loading Steam API...` and a bare `OK` two lines apart.
                outcome.beginAwaitingLoginVerdict()
            case .other(let raw) where outcome.isAwaitingLoginVerdict:
                if raw.trimmingCharacters(in: .whitespaces) == "OK" { outcome.recordLoginSucceeded() }
            case .loginResult(let succeeded, let detail):
                guard !succeeded else { outcome.recordLoginSucceeded(); break }
                // Having been asked for a code we had no answer for is the usual shape of "needs 2FA",
                // and is a materially different thing to tell the user than "sign-in failed".
                let awaitingCode = responder.wasPrompted(for: .twoFactorCode)
                    || responder.wasPrompted(for: .steamGuardCode)
                outcome.record(awaitingCode ? .twoFactorRequired : .loginFailed(detail: detail))
            case .success(let appID, _):
                outcome.recordSuccess(appID: appID)
            default:
                break
            }

                return nil
            }
        } onCancel: {
            process.interrupt()
        }

        if let failure = outcome.failure { throw failure }

        // Absence of an error is not proof of a sign-in. A login awaiting Steam Mobile App confirmation
        // that then times out produces neither an ERROR line nor a verdict on the `to Steam Public...`
        // line, so without this a timeout would be reported to the user as success.
        if requiresSuccessfulLogin, !outcome.loginSucceeded {
            throw diagnoseIncompleteLogin()
        }

        return process
    }

    /**
     Works out *why* a sign-in ended without a verdict.

     SteamCMD says nothing useful on stdout in this case, but it is explicit in its own connection log,
     which lives inside the scoped home Mythic owns.
     */
    private static func diagnoseIncompleteLogin() -> Failure {
        let connectionLogURL = homeDirectory
            .appending(path: "Library/Application Support/Steam/logs/connection_log.txt")

        guard let contents = try? String(contentsOf: connectionLogURL, encoding: .utf8) else {
            return .loginDidNotComplete
        }

        // Only the tail matters -- the file accumulates across runs.
        let tail = contents.split(whereSeparator: \.isNewline).suffix(40).joined(separator: "\n")

        // Only the explicit timeout counts. "Waiting for confirmation" on its own appears in *successful*
        // sign-ins too, and matching it reported a completed login as a timeout.
        if tail.contains("Timed out waiting for confirmation") {
            return .mobileConfirmationTimedOut
        }
        if tail.contains("Rate Limit Exceeded") {
            return .rateLimited
        }

        return .loginDidNotComplete
    }

    /// Collects the first terminal outcome seen on the stream.
    fileprivate final class OperationOutcome: Sendable {
        private let state: OSAllocatedUnfairLock<State> = .init(initialState: .init())

        var failure: Failure? { state.withLock(\.failure) }
        var succeededAppIDs: Set<String> { state.withLock(\.succeededAppIDs) }
        var loginSucceeded: Bool { state.withLock(\.loginSucceeded) }
        var isAwaitingLoginVerdict: Bool { state.withLock(\.isAwaitingLoginVerdict) }

        func record(_ failure: Failure) {
            state.withLock { if $0.failure == nil { $0.failure = failure } }
        }

        func recordSuccess(appID: String) {
            state.withLock { $0.succeededAppIDs.insert(appID) }
        }

        func recordLoginSucceeded() {
            state.withLock {
                $0.loginSucceeded = true
                $0.isAwaitingLoginVerdict = false
            }
        }

        func beginAwaitingLoginVerdict() {
            state.withLock { $0.isAwaitingLoginVerdict = true }
        }
    }

    private static func translate(_ failure: SteamCMDOutput.Failure) -> Failure {
        switch failure {
        case .invalidPassword:
            .invalidCredentials
        case .rateLimited:
            .rateLimited
        case .twoFactorMismatch:
            .twoFactorRequired
        case .installFailed(let appID, let reason):
            .appOperationFailed(appID: appID, reason: reason)
        case .appStateAfterUpdate(let appID, let stateFlags):
            .appOperationFailed(appID: appID, reason: "state 0x\(String(stateFlags, radix: 16))")
        case .timedOutWaitingForUpdate:
            .appOperationFailed(appID: "", reason: "timed out waiting for the update to start")
        }
    }

    /// Shared argument assembly. Order is load-bearing: ConVars, then `force_install_dir`, then `login`.
    private static func prepareProcess(
        commands: [Command],
        installDirectory: URL?,
        credentials: Credentials?,
        forcedPlatform: ForcedPlatform?,
        stopOnFailedCommand: Bool
    ) throws -> Process {
        var arguments: [String] = .init()

        // ConVars first; they change how later commands behave.
        // Defaults to 1 in SteamCMD itself, which is right for a single operation and wrong for a batch:
        // one unknown app ID makes `app_info_print` produce an empty block, and SteamCMD then abandons
        // every remaining command in the run. Measured: a 25-app metadata batch returned exactly one.
        arguments += ["+@ShutdownOnFailedCommand", stopOnFailedCommand ? "1" : "0"]
        arguments += ["+@NoPromptForPassword", credentials?.password == nil ? "1" : "0"]
        if let forcedPlatform {
            arguments += ["+@sSteamCmdForcePlatformType", forcedPlatform.rawValue]
        }

        // Then the install directory -- before login, never after.
        if let installDirectory {
            arguments += ["+force_install_dir", installDirectory.path(percentEncoded: false)]
        }

        if let credentials {
            arguments += ["+login", credentials.username]
        }

        arguments += commands.flatMap(\.arguments)
        arguments += ["+quit"]

        let process: Process = .init()
        process.executableURL = executableURL
        process.currentDirectoryURL = directory
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = homeDirectory.path(percentEncoded: false)
        process.environment = environment

        try FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)

        return process
    }

}

extension SteamCMD.OperationOutcome {
    struct State: Sendable {
        var failure: SteamCMD.Failure?
        var succeededAppIDs: Set<String> = .init()
        var loginSucceeded: Bool = false
        var isAwaitingLoginVerdict: Bool = false
    }
}
