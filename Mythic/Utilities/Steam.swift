//
//  Steam.swift
//  Mythic
//
//  Created on 12/3/2026.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import AppKit

enum Steam {
    static let rootPathUserDefaultsKey = "steamRootPath"
    
    static var configuredRootURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: rootPathUserDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
    }
    
    /// Default Steam installation root on macOS.
    static var defaultRootURL: URL? {
        let fileManager: FileManager = .default
        guard let applicationSupportURL = try? fileManager.url(for: .applicationSupportDirectory,
                                                               in: .userDomainMask,
                                                               appropriateFor: nil,
                                                               create: false) else {
            return nil
        }
        
        let steamURL = applicationSupportURL.appending(path: "Steam")
        guard fileManager.fileExists(atPath: steamURL.path) else { return nil }
        return steamURL
    }
    
    static var rootURL: URL? { configuredRootURL ?? defaultRootURL }
    static var isUsingCustomRootURL: Bool { configuredRootURL != nil }
    static let browserProtocolURL: URL = .init(string: "steam://")! // swiftlint:disable:this force_unwrapping
    static var isClientInstalled: Bool { NSWorkspace.shared.urlForApplication(toOpen: browserProtocolURL) != nil }
    
    static func containsLibraryMetadata(in steamRootURL: URL? = nil) -> Bool {
        guard let candidateRootURL = steamRootURL ?? rootURL else { return false }
        let libraryFoldersURL = candidateRootURL.appending(path: "steamapps").appending(path: "libraryfolders.vdf")
        return FileManager.default.fileExists(atPath: libraryFoldersURL.path)
    }
    
    enum ArtworkKind {
        case verticalLibraryCapsule
        case horizontalLibraryHero
    
        fileprivate var assetName: String {
            switch self {
            case .verticalLibraryCapsule: "library_600x900_2x.jpg"
            case .horizontalLibraryHero:  "library_hero.jpg"
            }
        }
    }
    
    /// Best-effort public library artwork URL. Steam's newer hashed asset pipeline
    /// is richer, but this legacy CDN pattern covers many titles without extra API calls.
    static func artworkURL(forAppID appID: String, kind: ArtworkKind) -> URL? {
        guard !appID.isEmpty, appID.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/\(kind.assetName)")
    }
    
    static func windowsExecutableURL(in steamRootURL: URL) -> URL {
        steamRootURL.appending(path: "steam.exe")
    }
    
    static func launchURL(forAppID appID: String, launchArguments: [String] = []) throws -> URL {
        guard !appID.isEmpty, appID.allSatisfy(\.isNumber) else {
            throw Error.invalidAppID(appID)
        }
        
        if launchArguments.isEmpty {
            // Delegate startup to the installed Steam client instead of attempting to
            // execute a Steam-managed binary directly. Steam owns DRM/bootstrap flow.
            return .init(string: "steam://rungameid/\(appID)")! // swiftlint:disable:this force_unwrapping
        }
        
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        guard let encodedArguments = launchArguments.joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: allowedCharacters),
              let url = URL(string: "steam://run/\(appID)//\(encodedArguments)/") else {
            throw Error.invalidLaunchArguments(launchArguments)
        }
        
        return url
    }

    struct LibraryFolder: Hashable {
        let url: URL

        var steamAppsURL: URL { url.appending(path: "steamapps") }
        var commonURL: URL { steamAppsURL.appending(path: "common") }
    }

    struct AppManifest: Hashable {
        let appID: String
        let name: String
        let installDirectoryName: String
        let libraryURL: URL
        let manifestURL: URL
        let buildID: String?
        let stateFlags: Int?
        let sizeOnDiskInBytes: Int64?

        var installationURL: URL {
            libraryURL
                .appending(path: "steamapps")
                .appending(path: "common")
                .appending(path: installDirectoryName)
        }
    }

    enum Error: LocalizedError {
        case defaultRootUnavailable
        case missingLibraryFoldersFile(URL)
        case missingSteamAppsDirectory(URL)
        case missingRequiredValue(file: URL, keyPath: String)
        case invalidVDF(file: URL, reason: String)
        case invalidAppID(String)
        case invalidLaunchArguments([String])
        case clientNotInstalled
        case unableToOpenLaunchURL(URL)
        case windowsPathRequiresContainer(String)
    
        var errorDescription: String? {
            switch self {
            case .defaultRootUnavailable:
                return "Steam is not installed in the default macOS location."
            case .missingLibraryFoldersFile(let file):
                return "Steam library metadata is missing at \(file.path)."
            case .missingSteamAppsDirectory(let directory):
                return "Steam library folder is missing its steamapps directory at \(directory.path)."
            case .missingRequiredValue(let file, let keyPath):
                return "Steam metadata file \(file.lastPathComponent) is missing required key \(keyPath)."
            case .invalidVDF(let file, let reason):
                return "Unable to parse Steam metadata file \(file.lastPathComponent): \(reason)"
            case .invalidAppID(let appID):
                return "Steam app ID \(appID) is invalid."
            case .invalidLaunchArguments(let arguments):
                return "Steam launch arguments could not be encoded: \(arguments.joined(separator: " "))"
            case .clientNotInstalled:
                return "Steam is not installed or has not registered the steam:// URL scheme."
            case .unableToOpenLaunchURL(let url):
                return "Unable to open Steam launch URL \(url.absoluteString)."
            case .windowsPathRequiresContainer(let path):
                return "The Windows Steam library path \(path) requires a Wine container to resolve on macOS."
            }
        }
    }

    /// Enumerate every Steam library root listed in `libraryfolders.vdf`.
    static func getLibraryFolders(in steamRootURL: URL? = nil, containerURL: URL? = nil) throws -> [LibraryFolder] {
        let fileManager: FileManager = .default
        let steamRootURL = try resolveSteamRootURL(from: steamRootURL)
        let libraryFoldersURL = steamRootURL.appending(path: "steamapps").appending(path: "libraryfolders.vdf")
    
        guard fileManager.fileExists(atPath: libraryFoldersURL.path) else {
            throw Error.missingLibraryFoldersFile(libraryFoldersURL)
        }
    
        let vdf = try parseVDF(at: libraryFoldersURL)
        guard let libraryFolders = vdf["libraryfolders"]?.objectValue else {
            throw Error.missingRequiredValue(file: libraryFoldersURL, keyPath: "libraryfolders")
        }
    
        return try libraryFolders
            .filter { $0.key.allSatisfy(\.isNumber) }
            .sorted(by: { lhs, rhs in lhs.key < rhs.key })
            .map { _, value in
                guard let folder = value.objectValue,
                      let path = folder["path"]?.stringValue else {
                    throw Error.missingRequiredValue(file: libraryFoldersURL, keyPath: "libraryfolders.<index>.path")
                }
    
                let resolvedPath = try resolveLibraryFolderPath(path, containerURL: containerURL)
                return LibraryFolder(url: resolvedPath)
            }
    }
    
    /// Parse every `appmanifest_<appid>.acf` file across all configured Steam libraries.
    static func getInstalledApps(in steamRootURL: URL? = nil, containerURL: URL? = nil) throws -> [AppManifest] {
        let fileManager: FileManager = .default
    
        return try getLibraryFolders(in: steamRootURL, containerURL: containerURL).flatMap { libraryFolder in
            guard fileManager.fileExists(atPath: libraryFolder.steamAppsURL.path) else {
                throw Error.missingSteamAppsDirectory(libraryFolder.steamAppsURL)
            }
    
            let manifestURLs = try fileManager.contentsOfDirectory(at: libraryFolder.steamAppsURL,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "acf" && $0.lastPathComponent.hasPrefix("appmanifest_") }
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    
            return try manifestURLs.map { try parseAppManifest(at: $0, libraryURL: libraryFolder.url) }
        }
    }
    
    static func getInstalledGames(in steamRootURL: URL? = nil, containerURL: URL? = nil) throws -> [SteamGame] {
        let steamRootURL = try resolveSteamRootURL(from: steamRootURL)
        return try getInstalledApps(in: steamRootURL, containerURL: containerURL)
            .map { SteamGame(manifest: $0, steamInstallationRootURL: steamRootURL, containerURL: containerURL) }
    }

    private static func resolveSteamRootURL(from explicitURL: URL?) throws -> URL {
        if let explicitURL { return explicitURL }
        guard let rootURL else { throw Error.defaultRootUnavailable }
        return rootURL
    }
    private static func resolveLibraryFolderPath(_ rawPath: String, containerURL: URL?) throws -> URL {
        let expandedPath = NSString(string: rawPath).expandingTildeInPath
        let normalizedWindowsPath = expandedPath.replacingOccurrences(of: "\\", with: "/")
    
        let windowsDriveRegex = try! Regex(#"^(?<drive>[A-Za-z]):(?<path>/.*)?$"#) // swiftlint:disable:this force_try
        if let match = try? windowsDriveRegex.firstMatch(in: normalizedWindowsPath),
           let driveSubstring = match["drive"]?.substring {
            let drive = driveSubstring.lowercased()
            guard let containerURL else { throw Error.windowsPathRequiresContainer(rawPath) }
    
            let relativePath = String(match["path"]?.substring ?? "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let baseURL: URL = if drive == "c" {
                containerURL.appending(path: "drive_c")
            } else {
                containerURL.appending(path: "dosdevices").appending(path: "\(drive):")
            }
    
            return relativePath.isEmpty ? baseURL : baseURL.appending(path: relativePath)
        }
    
        return URL(fileURLWithPath: expandedPath)
    }


    private static func parseAppManifest(at manifestURL: URL, libraryURL: URL) throws -> AppManifest {
        let vdf = try parseVDF(at: manifestURL)
        guard let appState = vdf["AppState"]?.objectValue else {
            throw Error.missingRequiredValue(file: manifestURL, keyPath: "AppState")
        }

        guard let appID = appState["appid"]?.stringValue else {
            throw Error.missingRequiredValue(file: manifestURL, keyPath: "AppState.appid")
        }

        guard let name = appState["name"]?.stringValue else {
            throw Error.missingRequiredValue(file: manifestURL, keyPath: "AppState.name")
        }

        guard let installDirectoryName = appState["installdir"]?.stringValue else {
            throw Error.missingRequiredValue(file: manifestURL, keyPath: "AppState.installdir")
        }

        return AppManifest(appID: appID,
                           name: name,
                           installDirectoryName: installDirectoryName,
                           libraryURL: libraryURL,
                           manifestURL: manifestURL,
                           buildID: appState["buildid"]?.stringValue,
                           stateFlags: Int(appState["StateFlags"]?.stringValue ?? ""),
                           sizeOnDiskInBytes: Int64(appState["SizeOnDisk"]?.stringValue ?? ""))
    }

    private static func parseVDF(at url: URL) throws -> [String: VDFValue] {
        let source = try String(contentsOf: url, encoding: .utf8)
        var parser = VDFParser(source: source, sourceURL: url)
        return try parser.parse()
    }
}

private enum VDFValue: Hashable {
    case string(String)
    case object([String: VDFValue])

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var objectValue: [String: VDFValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }
}

private struct VDFParser {
    let source: String
    let sourceURL: URL
    private var index: String.Index

    init(source: String, sourceURL: URL) {
        self.source = source
        self.sourceURL = sourceURL
        index = source.startIndex
    }

    mutating func parse() throws -> [String: VDFValue] {
        let object = try parseObjectBody(untilClosingBrace: false)
        skipIgnorableCharacters()

        guard index == source.endIndex else {
            throw Steam.Error.invalidVDF(file: sourceURL, reason: "unexpected trailing characters")
        }

        return object
    }

    private mutating func parseObjectBody(untilClosingBrace: Bool) throws -> [String: VDFValue] {
        var object: [String: VDFValue] = [:]

        while true {
            skipIgnorableCharacters()

            if index == source.endIndex {
                if untilClosingBrace {
                    throw Steam.Error.invalidVDF(file: sourceURL, reason: "unterminated object")
                }

                return object
            }

            if untilClosingBrace, peek() == "}" {
                advanceIndex()
                return object
            }

            let key = try parseQuotedString()
            skipIgnorableCharacters()

            if peek() == "{" {
                advanceIndex()
                object[key] = .object(try parseObjectBody(untilClosingBrace: true))
                continue
            }

            object[key] = .string(try parseQuotedString())
        }
    }

    private mutating func parseQuotedString() throws -> String {
        guard peek() == "\"" else {
            throw Steam.Error.invalidVDF(file: sourceURL, reason: "expected quoted string")
        }

        advanceIndex()
        var output = String()

        while index < source.endIndex {
            let character = source[index]
            advanceIndex()

            switch character {
            case "\\":
                guard index < source.endIndex else {
                    throw Steam.Error.invalidVDF(file: sourceURL, reason: "unterminated escape sequence")
                }

                let escapedCharacter = source[index]
                advanceIndex()

                switch escapedCharacter {
                case "n": output.append("\n")
                case "r": output.append("\r")
                case "t": output.append("\t")
                case "\\", "\"": output.append(escapedCharacter)
                default: output.append(escapedCharacter)
                }
            case "\"":
                return output
            default:
                output.append(character)
            }
        }

        throw Steam.Error.invalidVDF(file: sourceURL, reason: "unterminated quoted string")
    }

    private mutating func skipIgnorableCharacters() {
        while index < source.endIndex {
            let character = source[index]

            if character.isWhitespace {
                advanceIndex()
                continue
            }

            if character == "/",
               source.index(after: index) < source.endIndex,
               source[source.index(after: index)] == "/" {
                while index < source.endIndex, source[index] != "\n" {
                    advanceIndex()
                }
                continue
            }

            break
        }
    }

    private func peek() -> Character? {
        guard index < source.endIndex else { return nil }
        return source[index]
    }

    private mutating func advanceIndex() {
        index = source.index(after: index)
    }
}
