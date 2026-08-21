//
//  SteamCMDOutput.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation

/**
 Classification of a single line of SteamCMD output.

 Two properties of SteamCMD's output drive the design here, both verified against SteamCMD `1785799152`:

 1. **The bootstrapper is localized.** It starts in English, loads `steambootstrapper_<lang>.txt`, then
    switches mid-stream (observed switching to pt-BR: `Verificando se há atualizações...`). Only the
    numeric `[  0%]` / `[----]` prefixes are stable, so those are all we match. Everything emitted after
    `Loading Steam API...` comes from `steamconsole.dylib` and is **not** localized, so string matching is
    safe from that point on.

 2. **Prompts arrive without a trailing newline** and diagnostics interleave mid-line, so prompt detection
    uses `contains` rather than equality, and the caller must feed us whatever it has rather than waiting
    for a line terminator.
 */
enum SteamCMDOutput {
    enum Line: Equatable, Sendable {
        /// A depot download/verify progress tick.
        case progress(Progress)
        /// `Success! App '<id>' fully installed.` / `already up to date.`
        case success(appID: String, wasAlreadyUpToDate: Bool)
        /// A recognised failure.
        case failure(Failure)
        /// SteamCMD is waiting on stdin.
        case prompt(Prompt)
        /// The result of a `login` attempt.
        case loginResult(succeeded: Bool, detail: String?)
        /// Steam is waiting for the user to approve the sign-in in the Steam Mobile App.
        case awaitingMobileConfirmation
        /// A `login` line that carries no verdict yet. Steam prints `...to Steam Public...` and appends
        /// `OK` or `ERROR (...)` to that same physical line later, so an unresolved line means the
        /// attempt is in flight -- most often waiting on a Steam Mobile App confirmation.
        case loginInProgress
        /// Bootstrapper/self-update chatter. `percentage` is `nil` for the `[----]` indeterminate form.
        case bootstrap(percentage: Int?)
        /// Nothing we act on for control flow. Carries the raw line, because bulk output —
        /// `app_info_print`'s VDF blob, for one — arrives this way and callers need it.
        case other(String)
    }

    struct Progress: Equatable, Sendable {
        /// Raw `Update state (0x??)` value.
        var stateFlags: Int
        var phase: Phase
        /// 0.0 ... 100.0, as printed.
        var percentage: Double
        var currentBytes: Int64
        var totalBytes: Int64
    }

    /// Phase names as they appear in `steamconsole.dylib`, contiguous in the binary.
    enum Phase: Equatable, Sendable {
        case stopping, reconfiguring, preallocating, downloading, staging
        case committing, verifyingInstall, verifyingUpdate, finalizing, running, unknown
        case unrecognised(String)

        init(rawPhase: String) {
            switch rawPhase.trimmingCharacters(in: .whitespaces).lowercased() {
            case "stopping":            self = .stopping
            case "reconfiguring":       self = .reconfiguring
            case "preallocating":       self = .preallocating
            case "downloading":         self = .downloading
            case "staging":             self = .staging
            case "committing":          self = .committing
            case "verifying install":   self = .verifyingInstall
            case "verifying update":    self = .verifyingUpdate
            case "finalizing":          self = .finalizing
            case "running":             self = .running
            case "unknown":             self = .unknown
            case let other:             self = .unrecognised(other)
            }
        }

        /// Whether bytes are moving over the network, for `Progress.fileOperationKind`.
        var isDownloading: Bool {
            self == .downloading || self == .preallocating
        }
    }

    enum Prompt: Equatable, Hashable, Sendable {
        case password
        /// Emailed Steam Guard code.
        case steamGuardCode
        /// Mobile authenticator code.
        case twoFactorCode
    }

    enum Failure: Equatable, Sendable {
        case appStateAfterUpdate(appID: String, stateFlags: Int)
        case installFailed(appID: String, reason: String)
        case timedOutWaitingForUpdate(stateFlags: Int)
        case invalidPassword
        case twoFactorMismatch
        case rateLimited
    }

    // MARK: - Classification

    /// Classify one line. The line may retain ANSI escapes and a trailing `\r`; both are handled.
    static func classify(_ rawLine: String) -> Line {
        let line = stripANSIEscapes(rawLine)
            .replacingOccurrences(of: "\r", with: "")

        // Prompts are matched first: they arrive without a newline and can share a physical line with
        // preceding diagnostics, so `contains` is required, not equality.
        if line.contains("Two-factor code:") { return .prompt(.twoFactorCode) }
        if line.contains("Steam Guard code:") { return .prompt(.steamGuardCode) }
        if line.contains("password:") { return .prompt(.password) }

        if let match = line.firstMatch(of: #/^\s*Update state \(0x([0-9A-Fa-f]+)\) ([^,]+), progress: (\d+\.\d+) \((\d+) / (\d+)\)/#) {
            return .progress(
                Progress(
                    stateFlags: Int(match.output.1, radix: 16) ?? 0,
                    phase: Phase(rawPhase: String(match.output.2)),
                    percentage: Double(match.output.3) ?? 0,
                    currentBytes: Int64(match.output.4) ?? 0,
                    totalBytes: Int64(match.output.5) ?? 0
                )
            )
        }

        if let match = line.firstMatch(of: #/^Success! App '(\d+)' (fully installed|already up to date)\./#) {
            return .success(appID: String(match.output.1),
                            wasAlreadyUpToDate: match.output.2 == "already up to date")
        }

        if let match = line.firstMatch(of: #/^\s*Update state \(0x([0-9A-Fa-f]+)\) : Timed out waiting for update to start/#) {
            return .failure(.timedOutWaitingForUpdate(stateFlags: Int(match.output.1, radix: 16) ?? 0))
        }

        if let match = line.firstMatch(of: #/^Error! App '(\d+)' state is 0x([0-9A-Fa-f]+) after update job\./#) {
            return .failure(.appStateAfterUpdate(appID: String(match.output.1),
                                                 stateFlags: Int(match.output.2, radix: 16) ?? 0))
        }

        if let match = line.firstMatch(of: #/^ERROR! Failed to install app '(\d+)' \(([^)]+)\)/#) {
            return .failure(.installFailed(appID: String(match.output.1),
                                           reason: String(match.output.2)))
        }

        if line.contains("Two-factor code mismatch") { return .failure(.twoFactorMismatch) }
        if line.contains("Rate Limit Exceeded") { return .failure(.rateLimited) }

        // Login outcome. The modern shape is `...to Steam Public...ERROR (Invalid Password)`, *not* the
        // legacy `FAILED login with result code` that most third-party parsers still match for.
        // The mobile-authenticator flow reports its own outcome, on its own line -- `to Steam Public...`
        // never gains a verdict in that case. Verbatim from a real successful sign-in:
        //   Please confirm the login in the Steam Mobile app on your phone.
        //   Waiting for confirmation...
        //   Waiting for confirmation...OK
        if line.contains("Waiting for confirmation") {
            return line.hasSuffix("OK")
                ? .loginResult(succeeded: true, detail: nil)
                : .awaitingMobileConfirmation
        }

        if line.contains("Please confirm the login in the Steam Mobile app") {
            return .awaitingMobileConfirmation
        }

        if line.contains("to Steam Public...") {
            if line.hasSuffix("OK") { return .loginResult(succeeded: true, detail: nil) }
            if let match = line.firstMatch(of: #/(?:ERROR|FAILED)\s*\(([^)]+)\)/#) {
                let detail = String(match.output.1)
                if detail == "Invalid Password" { return .failure(.invalidPassword) }
                return .loginResult(succeeded: false, detail: detail)
            }
            // No verdict on this line yet. Reading that as a failure was wrong: Steam appends the result
            // to this same physical line once it has one, and while it waits for a Steam Mobile App
            // confirmation there is nothing appended at all.
            return .loginInProgress
        }

        // Bootstrapper. Numeric prefixes only — the words after them are localized.
        if let match = line.firstMatch(of: #/^\[\s*(\d+)%\]/#) {
            return .bootstrap(percentage: Int(match.output.1))
        }
        if line.hasPrefix("[----]") {
            return .bootstrap(percentage: nil)
        }

        return .other(line)
    }

    /// SteamCMD writes its interactive prompt as `Steam>\u{1B}[0m` — strip escapes before matching.
    static func stripANSIEscapes(_ text: String) -> String {
        text.replacing(#/\x1B\[[0-9;]*[A-Za-z]/#, with: "")
    }

    // MARK: - Expression reference
    //
    // The literals live inline at their use sites above: `Regex` is not `Sendable`, so holding them as
    // `static let` is a hard error under Swift 6 strict concurrency. They are reproduced here for review:
    //
    //   progress   ^\s*Update state \(0x([0-9A-Fa-f]+)\) ([^,]+), progress: (\d+\.\d+) \((\d+) / (\d+)\)
    //   success    ^Success! App '(\d+)' (fully installed|already up to date)\.
    //   appState   ^Error! App '(\d+)' state is 0x([0-9A-Fa-f]+) after update job\.
    //   install    ^ERROR! Failed to install app '(\d+)' \(([^)]+)\)
    //   timeout    ^\s*Update state \(0x([0-9A-Fa-f]+)\) : Timed out waiting for update to start
    //   login      (?:ERROR|FAILED)\s*\(([^)]+)\)
    //   bootstrap  ^\[\s*(\d+)%\]
    //
    // Note the leading whitespace on every progress line, and that the timeout variant is structurally
    // different from the progress line (colon-space, no byte pair) rather than a special case of it.
}
