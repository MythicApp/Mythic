//
//  ValveDataFormat.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation

/**
 A minimal reader for Valve's KeyValues text format (VDF), used by `appmanifest_<appid>.acf`,
 `libraryfolders.vdf` and `config.vdf`.

 This exists because `StorefrontGameManager.fetchUpdateAvailability(for:)` and
 `isFileVerificationRequired(for:)` are **synchronous and throwing** — they cannot shell out to
 `steamcmd +app_status`. The only synchronously readable source of truth for a Steam title's state is
 the on-disk `.acf` manifest, so a parser is required rather than merely convenient.

 Scope is deliberately narrow: read-only, no writing, no binary VDF. Duplicate keys resolve last-wins,
 which matches how Steam's own reader behaves for the files we consume.
 */
enum ValveDataFormat {
    indirect enum Value: Equatable, Sendable {
        case string(String)
        case object([String: Value])
    }

    enum ParseError: LocalizedError, Equatable {
        case unterminatedString(atOffset: Int)
        case expectedKey(butFound: String, atOffset: Int)
        case expectedValue(forKey: String, atOffset: Int)
        case unbalancedBrace(atOffset: Int)

        var errorDescription: String? {
            switch self {
            case .unterminatedString(let offset):
                "Unterminated quoted string at offset \(offset)."
            case .expectedKey(let found, let offset):
                "Expected a key at offset \(offset), found \"\(found)\"."
            case .expectedValue(let key, let offset):
                "Key \"\(key)\" at offset \(offset) has no value."
            case .unbalancedBrace(let offset):
                "Unbalanced brace at offset \(offset)."
            }
        }
    }

    static func parse(_ text: String) throws -> [String: Value] {
        var scanner = Scanner(scalars: Array(text.unicodeScalars))
        let root = try scanner.parseObjectBody(isTopLevel: true)
        return root
    }

    static func parse(contentsOf url: URL) throws -> [String: Value] {
        try parse(String(contentsOf: url, encoding: .utf8))
    }
}

// MARK: - Accessors

extension ValveDataFormat.Value {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var objectValue: [String: ValveDataFormat.Value]? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// Steam is not internally consistent about casing — a single `.acf` carries both `appid` and
    /// `StateFlags` — so lookups are case-insensitive by design.
    subscript(key: String) -> ValveDataFormat.Value? {
        guard case .object(let dictionary) = self else { return nil }
        if let exact = dictionary[key] { return exact }
        return dictionary.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }

    /// Valve stores every scalar as a quoted string, integers included.
    var integerValue: Int? {
        guard let stringValue else { return nil }
        return Int(stringValue.trimmingCharacters(in: .whitespaces))
    }
}

extension Dictionary where Key == String, Value == ValveDataFormat.Value {
    subscript(caseInsensitive key: String) -> ValveDataFormat.Value? {
        if let exact = self[key] { return exact }
        return first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}

// MARK: - Scanner

private extension ValveDataFormat {
    struct Scanner {
        let scalars: [Unicode.Scalar]
        var index: Int = 0

        init(scalars: [Unicode.Scalar]) {
            self.scalars = scalars
        }

        var isAtEnd: Bool { index >= scalars.count }

        mutating func skipIgnored() {
            while index < scalars.count {
                let scalar = scalars[index]

                if scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" {
                    index += 1
                } else if scalar == "/", index + 1 < scalars.count, scalars[index + 1] == "/" {
                    while index < scalars.count, scalars[index] != "\n" { index += 1 }
                } else if scalar == "[" {
                    // Platform conditional, e.g. `"key" "value" [$WIN32]`. Not meaningful on macOS.
                    while index < scalars.count, scalars[index] != "]" { index += 1 }
                    if index < scalars.count { index += 1 }
                } else {
                    return
                }
            }
        }

        mutating func readToken() throws -> String? {
            skipIgnored()
            guard index < scalars.count else { return nil }

            let scalar = scalars[index]
            if scalar == "{" || scalar == "}" {
                index += 1
                return String(scalar)
            }

            if scalar == "\"" {
                let openedAt = index
                index += 1
                var result = ""
                while index < scalars.count {
                    let current = scalars[index]
                    if current == "\\", index + 1 < scalars.count {
                        index += 1
                        switch scalars[index] {
                        case "n": result.unicodeScalars.append("\n")
                        case "t": result.unicodeScalars.append("\t")
                        case "\\": result.unicodeScalars.append("\\")
                        case "\"": result.unicodeScalars.append("\"")
                        case let other: result.unicodeScalars.append(other)
                        }
                        index += 1
                    } else if current == "\"" {
                        index += 1
                        return result
                    } else {
                        result.unicodeScalars.append(current)
                        index += 1
                    }
                }
                throw ParseError.unterminatedString(atOffset: openedAt)
            }

            // Unquoted token — legal in hand-written VDF, and Steam emits it for some config keys.
            var result = ""
            while index < scalars.count {
                let current = scalars[index]
                if current == " " || current == "\t" || current == "\n" || current == "\r"
                    || current == "\"" || current == "{" || current == "}" {
                    break
                }
                result.unicodeScalars.append(current)
                index += 1
            }
            return result.isEmpty ? nil : result
        }

        mutating func parseObjectBody(isTopLevel: Bool) throws -> [String: Value] {
            var result: [String: Value] = .init()

            while true {
                let offsetBeforeKey = index
                guard let key = try readToken() else {
                    if isTopLevel { return result }
                    throw ParseError.unbalancedBrace(atOffset: offsetBeforeKey)
                }

                if key == "}" {
                    if isTopLevel { throw ParseError.unbalancedBrace(atOffset: offsetBeforeKey) }
                    return result
                }

                if key == "{" {
                    throw ParseError.expectedKey(butFound: key, atOffset: offsetBeforeKey)
                }

                let offsetBeforeValue = index
                guard let token = try readToken() else {
                    throw ParseError.expectedValue(forKey: key, atOffset: offsetBeforeValue)
                }

                if token == "{" {
                    result[key] = .object(try parseObjectBody(isTopLevel: false))
                } else if token == "}" {
                    throw ParseError.expectedValue(forKey: key, atOffset: offsetBeforeValue)
                } else {
                    result[key] = .string(token)
                }
            }
        }
    }
}

// MARK: - App manifest

extension ValveDataFormat {
    /// The subset of `appmanifest_<appid>.acf` Mythic acts on.
    struct AppManifest: Equatable, Sendable {
        var appID: String
        var name: String?
        var installDirectoryName: String?
        var stateFlags: StateFlags
        var buildID: Int?
        var targetBuildID: Int?
        var sizeOnDisk: Int64?

        /// `buildid` lagging `TargetBuildID` is the signal Steam itself uses; `updateRequired` alone
        /// misses a queued-but-not-yet-flagged update.
        var isUpdateAvailable: Bool {
            if stateFlags.contains(.updateRequired) { return true }
            guard let buildID, let targetBuildID, targetBuildID != 0 else { return false }
            return buildID != targetBuildID
        }

        var requiresVerification: Bool {
            !stateFlags.isDisjoint(with: [.filesMissing, .filesCorrupt])
        }

        var isFullyInstalled: Bool {
            stateFlags.contains(.fullyInstalled)
        }
    }

    static func parseAppManifest(_ text: String) throws -> AppManifest? {
        let root = try parse(text)
        guard let state = root[caseInsensitive: "AppState"],
              let appID = state["appid"]?.stringValue else { return nil }

        return AppManifest(
            appID: appID,
            name: state["name"]?.stringValue,
            installDirectoryName: state["installdir"]?.stringValue,
            stateFlags: .init(rawValue: state["StateFlags"]?.integerValue ?? 0),
            buildID: state["buildid"]?.integerValue,
            targetBuildID: state["TargetBuildID"]?.integerValue,
            sizeOnDisk: state["SizeOnDisk"]?.integerValue.map(Int64.init)
        )
    }

    static func parseAppManifest(contentsOf url: URL) throws -> AppManifest? {
        try parseAppManifest(String(contentsOf: url, encoding: .utf8))
    }
}

extension ValveDataFormat.AppManifest {
    /// Bit flags Steam writes to `AppState/StateFlags`.
    struct StateFlags: OptionSet, Equatable, Sendable {
        let rawValue: Int

        static let uninstalled       = StateFlags(rawValue: 1 << 0)   // 1
        static let updateRequired    = StateFlags(rawValue: 1 << 1)   // 2
        static let fullyInstalled    = StateFlags(rawValue: 1 << 2)   // 4
        static let updateQueued      = StateFlags(rawValue: 1 << 3)   // 8
        static let updateOptional    = StateFlags(rawValue: 1 << 4)   // 16
        static let filesMissing      = StateFlags(rawValue: 1 << 5)   // 32
        static let sharedOnly        = StateFlags(rawValue: 1 << 6)   // 64
        static let filesCorrupt      = StateFlags(rawValue: 1 << 7)   // 128
        static let updateRunning     = StateFlags(rawValue: 1 << 8)   // 256
        static let updatePaused      = StateFlags(rawValue: 1 << 9)   // 512
        static let updateStarted     = StateFlags(rawValue: 1 << 10)  // 1024
        static let uninstalling      = StateFlags(rawValue: 1 << 11)  // 2048
        static let reconfiguring     = StateFlags(rawValue: 1 << 16)  // 65536
        static let validating        = StateFlags(rawValue: 1 << 17)  // 131072
    }
}

// MARK: - App info

extension ValveDataFormat {
    /// The subset of `app_info_print` output Mythic acts on.
    ///
    /// Deliberately free of `Game.Platform`: this layer stays dependency-free so it can be checked
    /// standalone. Callers map ``operatingSystems`` onto Mythic's platform type.
    struct AppInfo: Equatable, Sendable {
        var appID: String
        var name: String
        /// Public-branch download size in bytes, summed across numeric depots, if Steam reports any.
        var downloadSize: Int64?
        /// Raw `common/oslist` tokens, e.g. `["windows", "macos"]`.
        var operatingSystems: Set<String>
        /// `config/installdir` — the folder name Steam installs the title into.
        var installDirectoryName: String?
        /// `config/launch` entries, in the order Steam lists them.
        var launchOptions: [LaunchOption]
        /// `common/type`, lowercased. Steam is inconsistent about casing here — observed as both `game`
        /// (Terraria, Dota 2) and `Game` (Palworld) in the same batch — so it is normalised on the way in.
        var type: String?

        var isGame: Bool { type == "game" }

        /// A launch option runnable on `operatingSystem`, preferring the one Steam marks `default`.
        func preferredLaunchOption(forOperatingSystem operatingSystem: String) -> LaunchOption? {
            let candidates = launchOptions.filter {
                // An empty oslist means "any platform", which is how single-platform titles are listed.
                $0.operatingSystems.isEmpty || $0.operatingSystems.contains(operatingSystem)
            }

            return candidates.first { $0.type == "default" } ?? candidates.first
        }
    }

    struct LaunchOption: Equatable, Sendable {
        var executable: String
        var arguments: String?
        /// `default`, `option1`, `none`, ...
        var type: String?
        /// `config/oslist` for this option; empty means unrestricted.
        var operatingSystems: Set<String>
        var description: String?
    }

    /**
     Extracts an ``AppInfo`` from raw `app_info_print` output.

     The VDF blob is wrapped in SteamCMD's own startup and shutdown chatter, so the balanced
     `"<appid>" { ... }` block is isolated by brace depth before parsing.

     Feeding the trailing chatter to the parser is **not** safe, which is why it is cut here rather than
     tolerated: `Unloading Steam API...OK` tokenises to three tokens, leaving `API...OK` as a key with no
     value, and the parser rightly throws. Whether it throws depends on whether an odd or even number of
     trailing tokens happens to follow — so a version that parsed to the end of the input would work or
     fail based on how much chatter Steam emitted that run.
     */
    /**
     Isolates the balanced `"<id>" { ... }` block for `id` out of a larger SteamCMD transcript.

     Necessary because the blob is wrapped in SteamCMD's own chatter, and feeding that chatter to the
     parser is not safe: `Unloading Steam API...OK` tokenises to three tokens, leaving `API...OK` as a
     key with no value, and the parser rightly throws. Whether it throws at all depends on whether an odd
     or even number of trailing tokens happens to follow, so a version that parsed to end-of-input would
     work or fail based on how much Steam printed that run.
     */
    static func isolateBlock(id: String, from output: String) -> String? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard let start = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "\"\(id)\""
        }) else { return nil }

        var depth = 0
        var hasOpened = false
        for index in start..<lines.count {
            depth += lines[index].filter { $0 == "{" }.count
            if depth > 0 { hasOpened = true }
            depth -= lines[index].filter { $0 == "}" }.count

            if hasOpened, depth <= 0 {
                return lines[start...index].joined(separator: "\n")
            }
        }

        return nil
    }

    static func parseAppInfo(appID: String, from output: String) -> AppInfo? {
        guard let block = isolateBlock(id: appID, from: output),
              let root = try? parse(block),
              let app = root[caseInsensitive: appID],
              let name = app["common"]?["name"]?.stringValue
        else { return nil }

        let operatingSystems = Set(
            (app["common"]?["oslist"]?.stringValue ?? .init())
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )

        // Depot keys are numeric; `branches`, `baselanguages` and `workshopdepot` sit alongside them.
        var downloadSize: Int64 = 0
        for (key, depot) in app["depots"]?.objectValue ?? .init() where Int(key) != nil {
            if let download = depot["manifests"]?["public"]?["download"]?.integerValue {
                downloadSize += Int64(download)
            }
        }

        let configuration = app["config"]

        // Steam keys launch entries by stringified index; sort numerically so option order is Steam's.
        let launchOptions: [LaunchOption] = (configuration?["launch"]?.objectValue ?? .init())
            .sorted { Int($0.key) ?? .max < Int($1.key) ?? .max }
            .compactMap { _, entry in
                guard let executable = entry["executable"]?.stringValue, !executable.isEmpty else { return nil }

                return LaunchOption(
                    executable: executable,
                    arguments: entry["arguments"]?.stringValue,
                    type: entry["type"]?.stringValue,
                    operatingSystems: Set(
                        (entry["config"]?["oslist"]?.stringValue ?? .init())
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    ),
                    description: entry["description"]?.stringValue
                )
            }

        return .init(appID: appID,
                     name: name,
                     downloadSize: downloadSize > 0 ? downloadSize : nil,
                     operatingSystems: operatingSystems,
                     installDirectoryName: configuration?["installdir"]?.stringValue,
                     launchOptions: launchOptions,
                     type: app["common"]?["type"]?.stringValue?.lowercased())
    }
}

// MARK: - Licenses

extension ValveDataFormat {
    /**
     One entry of `licenses_print` output.

     `licenses_print` is not VDF — it is a human-readable listing — so it gets its own reader rather than
     going through the KeyValues parser.
     */
    struct LicensePackage: Equatable, Sendable {
        var packageID: String
        /// App IDs actually printed on the line.
        var listedAppIDs: [String]
        /// The count Steam claims the package holds.
        var totalAppCount: Int

        /// Whether Steam elided part of the list. It caps the printed set, so a package holding more apps
        /// than it printed has to be read again through `package_info_print`.
        var isTruncated: Bool { listedAppIDs.count < totalAppCount }
    }

    /// Parses the `License packageID N:` / ` - Apps : …` pairs out of `licenses_print` output.
    static func parseLicenses(from output: String) -> [LicensePackage] {
        var packages: [LicensePackage] = .init()
        var currentPackageID: String?

        for line in output.split(whereSeparator: \.isNewline) {
            if let match = line.firstMatch(of: #/^License packageID (\d+):/#) {
                currentPackageID = String(match.output.1)
                continue
            }

            // Note the tab between "Apps" and the colon in real output.
            guard let match = line.firstMatch(of: #/^\s*-\s*Apps\s*:\s*(.*?)\s*\((\d+) in total\)\s*$/#),
                  let packageID = currentPackageID
            else { continue }

            packages.append(
                .init(packageID: packageID,
                      listedAppIDs: String(match.output.1).matches(of: #/\d+/#).map { String($0.output) },
                      totalAppCount: Int(match.output.2) ?? 0)
            )
            currentPackageID = nil
        }

        return packages
    }

    /// Pulls the complete app ID list out of a `package_info_print` blob.
    static func parsePackageAppIDs(packageID: String, from output: String) -> [String] {
        guard let block = isolateBlock(id: packageID, from: output),
              let root = try? parse(block),
              let appIDs = root[caseInsensitive: packageID]?["appids"]?.objectValue
        else { return [] }

        // Keyed by stringified index; sort numerically so the order is Steam's.
        return appIDs
            .sorted { Int($0.key) ?? .max < Int($1.key) ?? .max }
            .compactMap { $0.value.stringValue }
    }
}
