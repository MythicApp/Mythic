//
//  SteamClient.swift
//  Mythic
//

import AppKit
import Foundation
import OSLog
import os

enum SteamClient {
    static let log = Logger.custom(category: "steamClient")
    static let gameIDPrefix = "steam_"
    static let clientBundleIdentifier = "com.valvesoftware.steam"

    private static let appIDPattern = #"^[0-9]{1,10}$"#
    private static let steamExecutable = "steam.exe"
    private static let cacheLifetime: TimeInterval = 5

    private struct InstalledAppsCache: Sendable {
        let refreshedAt: Date
        let apps: [InstalledApp]
    }

    private static let installedAppsCache = OSAllocatedUnfairLock<InstalledAppsCache?>(initialState: nil)

    static func isValidAppID(_ appID: String) -> Bool {
        appID.range(of: appIDPattern, options: .regularExpression) != nil
    }

    static func appID(fromGameID id: String) -> String? {
        guard id.hasPrefix(gameIDPrefix) else { return nil }
        let appID = String(id.dropFirst(gameIDPrefix.count))
        return isValidAppID(appID) ? appID : nil
    }

    static func gameID(forAppID appID: String) -> String? {
        guard isValidAppID(appID) else { return nil }
        return gameIDPrefix + appID
    }

    static let maximumTitleLength = 256

    /// Cleans an untrusted Steam-supplied display string (manifest `name`, Web API game `name`, persona name):
    /// control characters and line/paragraph separators become spaces, format characters (bidi overrides such as
    /// U+202E, zero-width characters) are dropped, and the result is trimmed and capped. `nil` if nothing is left.
    static func sanitizedTitle(_ raw: String) -> String? {
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control, .lineSeparator, .paragraphSeparator:
                scalars.append(" ")
            case .format, .surrogate:
                continue
            default:
                scalars.append(scalar)
            }
        }
        let title = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return String(title.prefix(maximumTitleLength))
    }

    static var isNativeClientInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: clientBundleIdentifier) != nil
    }

    static var nativeSteamRoot: URL? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Steam", isDirectory: true)
        return isDirectory(root) ? root : nil
    }

    static func windowsSteamRoot(containerURL: URL) -> URL? {
        let driveC = containerURL.appendingPathComponent("drive_c", isDirectory: true)
        let candidates = [
            driveC.appendingPathComponent("Program Files (x86)", isDirectory: true)
                .appendingPathComponent("Steam", isDirectory: true),
            driveC.appendingPathComponent("Program Files", isDirectory: true)
                .appendingPathComponent("Steam", isDirectory: true)
        ]
        return candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent(steamExecutable).path)
        }
    }

    struct InstallLocation: Hashable, Sendable {
        let steamRoot: URL
        let containerURL: URL?

        var platform: Game.Platform {
            containerURL == nil ? .macOS : .windows
        }
    }

    static var installLocations: [InstallLocation] {
        var locations: [InstallLocation] = []
        if let root = nativeSteamRoot {
            locations.append(InstallLocation(steamRoot: root, containerURL: nil))
        }
        for containerURL in Wine.containerURLs.sorted(by: { $0.path < $1.path }) {
            guard let root = windowsSteamRoot(containerURL: containerURL) else { continue }
            locations.append(InstallLocation(steamRoot: root, containerURL: containerURL))
        }
        return locations
    }

    static func libraryFolders(of location: InstallLocation) -> [URL] {
        let rootSteamApps = location.steamRoot.appendingPathComponent("steamapps", isDirectory: true)
        var folders = [rootSteamApps]
        let libraryFile = rootSteamApps.appendingPathComponent("libraryfolders.vdf")

        do {
            let parsed = try VDF.parse(contentsOf: libraryFile)
            let libraries = parsed["libraryfolders"] ?? parsed
            for entry in libraries.children {
                let path = entry.value.stringValue ?? entry.value["path"]?.stringValue
                guard let path, let libraryURL = libraryURL(path, for: location) else { continue }
                let steamApps = libraryURL.appendingPathComponent("steamapps", isDirectory: true)
                if isDirectory(steamApps) {
                    folders.append(steamApps)
                }
            }
        } catch {
            log.debug("Unable to read Steam library folders at \(libraryFile.path): \(error.localizedDescription)")
        }

        var seen = Set<String>()
        return folders.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    struct InstalledApp: Hashable, Sendable {
        let appID: String
        let name: String
        let installDirectory: URL
        let location: InstallLocation
        let stateFlags: Int

        var isUpdateRequired: Bool { stateFlags & 2 != 0 }
    }

    static func installedApps(forceRefresh: Bool = false) -> [InstalledApp] {
        if !forceRefresh,
           let cached = installedAppsCache.withLock({ $0 }),
           Date().timeIntervalSince(cached.refreshedAt) < cacheLifetime {
            return cached.apps
        }

        let apps = installLocations.flatMap { location in
            libraryFolders(of: location).flatMap { steamApps in
                installedApps(in: steamApps, location: location)
            }
        }
        installedAppsCache.withLock {
            $0 = InstalledAppsCache(refreshedAt: .now, apps: apps)
        }
        return apps
    }

    static func installedApp(appID: String) -> InstalledApp? {
        guard isValidAppID(appID) else { return nil }
        return installedApps().first { $0.appID == appID }
    }

    static func imageURL(appID: String, vertical: Bool) -> URL? {
        guard isValidAppID(appID) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "cdn.cloudflare.steamstatic.com"
        components.path = vertical
            ? "/steam/apps/\(appID)/library_600x900_2x.jpg"
            : "/steam/apps/\(appID)/header.jpg"
        return components.url
    }

    static func steamURL(action: String, appID: String) -> URL? {
        guard isValidAppID(appID),
              ["rungameid", "install", "uninstall", "validate"].contains(action) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "steam"
        components.host = action
        components.path = "/\(appID)"
        return components.url
    }

    struct ClientNotInstalledError: LocalizedError {
        var errorDescription: String? {
            String(localized: "The Steam client is not installed for this platform.")
        }
    }

    struct InvalidAppIDError: LocalizedError {
        var errorDescription: String? {
            String(localized: "The Steam AppID is invalid.")
        }
    }

    static func perform(action: String,
                        appID: String,
                        platform: Game.Platform,
                        containerURL: URL?,
                        extraArguments: [String] = []) async throws {
        guard isValidAppID(appID) else { throw InvalidAppIDError() }
        guard ["rungameid", "install", "uninstall", "validate"].contains(action) else {
            throw CocoaError(.coderInvalidValue)
        }
        guard let url = steamURL(action: action, appID: appID) else {
            throw InvalidAppIDError()
        }

        switch platform {
        case .macOS:
            // Hand the URL to Valve's Steam app explicitly rather than to whichever app currently claims the `steam:`
            // scheme (any installed app can register it and would otherwise receive these actions).
            guard let steamAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: clientBundleIdentifier) else {
                throw ClientNotInstalledError()
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            do {
                _ = try await NSWorkspace.shared.open([url], withApplicationAt: steamAppURL, configuration: configuration)
            } catch {
                log.error("Unable to hand \(action, privacy: .public) to the Steam client: \(error.localizedDescription)")
                throw ClientNotInstalledError()
            }
        case .windows:
            guard let containerURL,
                  let steamRoot = windowsSteamRoot(containerURL: containerURL) else {
                throw ClientNotInstalledError()
            }
            guard Engine.isInstalled else { throw Engine.NotInstalledError() }

            let executableURL = steamRoot.appendingPathComponent(steamExecutable)
            let arguments: [String]
            if action == "rungameid" {
                arguments = ["-applaunch", appID] + extraArguments
            } else {
                arguments = [url.absoluteString]
            }
            let environment = try Wine.assembleEnvironmentVariables(forContainerAtURL: containerURL)
            // `Wine.transformProcess` replaces `executableURL` with wine64, so steam.exe must be the first argument
            // (same pattern as `LocalGameManager`).
            let process = Process()
            process.arguments = [executableURL.path] + arguments
            process.environment = environment
            Wine.transformProcess(process, containerURL: containerURL)
            try process.run()
        }
    }

    static func fetchInstalledGames() -> [SteamGame] {
        installedApps(forceRefresh: true).compactMap { app in
            guard let gameID = gameID(forAppID: app.appID) else { return nil }
            return SteamGame(
                id: gameID,
                title: app.name,
                installationState: .installed(location: app.installDirectory, platform: app.location.platform),
                containerURL: app.location.containerURL
            )
        }
    }

    /// Main-actor isolated so the non-Sendable `SteamGame` results never cross an isolation boundary (Swift 6).
    @MainActor static func fetchOwnedGames() async throws -> [SteamGame]? {
        guard let steamID = SteamAuth.currentSteamID,
              SteamConfig.webAPIKey != nil else {
            log.debug("Skipping owned-games refresh because Steam sign-in or a Web API key is unavailable.")
            return nil
        }

        let ownedGames = try await SteamWebAPI.getOwnedGames(steamID: steamID)
        return ownedGames.compactMap { ownedGame in
            let appID = String(ownedGame.appid)
            guard let gameID = gameID(forAppID: appID) else { return nil }
            return SteamGame(
                id: gameID,
                title: ownedGame.name.flatMap { sanitizedTitle($0) } ?? String(localized: "Steam App \(appID)"),
                installationState: .uninstalled
            )
        }
    }

    private static func installedApps(in steamApps: URL, location: InstallLocation) -> [InstalledApp] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: steamApps,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            log.debug("Unable to list Steam manifests in \(steamApps.path): \(error.localizedDescription)")
            return []
        }

        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { manifestURL in
            let filename = manifestURL.lastPathComponent
            guard filename.hasPrefix("appmanifest_"),
                  filename.hasSuffix(".acf") else { return nil }
            let appID = String(filename.dropFirst("appmanifest_".count).dropLast(".acf".count))
            guard isValidAppID(appID) else { return nil }
            return installedApp(appID: appID, manifestURL: manifestURL, steamApps: steamApps, location: location)
        }
    }

    private static func installedApp(appID: String,
                                     manifestURL: URL,
                                     steamApps: URL,
                                     location: InstallLocation) -> InstalledApp? {
        guard isValidAppID(appID) else { return nil }
        let manifest: VDF.Node
        do {
            manifest = try VDF.parse(contentsOf: manifestURL)
        } catch {
            log.debug("Unable to read Steam manifest \(manifestURL.path): \(error.localizedDescription)")
            return nil
        }

        guard let state = manifest["AppState"],
              state["appid"]?.stringValue == appID,
              let flagsString = state["StateFlags"]?.stringValue,
              let flags = Int(flagsString),
              flags & 4 != 0,
              let installDirectoryName = state["installdir"]?.stringValue,
              let installDirectory = safeInstallDirectory(installDirectoryName, steamApps: steamApps),
              isDirectory(installDirectory),
              let rawName = state["name"]?.stringValue,
              let name = sanitizedTitle(rawName) else {
            return nil
        }

        return InstalledApp(
            appID: appID,
            name: name,
            installDirectory: installDirectory,
            location: location,
            stateFlags: flags
        )
    }

    private static func safeInstallDirectory(_ name: String, steamApps: URL) -> URL? {
        let normalizedName = name.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty,
              !normalizedName.contains("/"),
              !normalizedName.contains("\\"),
              !normalizedName.contains(".."),
              normalizedName != "." else {
            return nil
        }

        let commonDirectory = steamApps
            .appendingPathComponent("common", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let resolvedDirectory = commonDirectory
            .appendingPathComponent(normalizedName, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let commonPath = commonDirectory.path.hasSuffix("/") ? commonDirectory.path : commonDirectory.path + "/"
        guard resolvedDirectory.path.hasPrefix(commonPath) else { return nil }
        return resolvedDirectory
    }

    private static func libraryURL(_ path: String, for location: InstallLocation) -> URL? {
        guard let containerURL = location.containerURL else {
            guard path.hasPrefix("/") else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }

        let windowsPath = path.replacingOccurrences(of: "\\", with: "/")
        guard windowsPath.range(of: #"^[Cc]:/"#, options: .regularExpression) != nil else { return nil }
        let components = String(windowsPath.dropFirst(3)).split(separator: "/")
        guard !components.contains(".."),
              !components.contains(".") else {
            return nil
        }
        let driveC = containerURL.appendingPathComponent("drive_c", isDirectory: true)
        return components.reduce(driveC) {
            $0.appendingPathComponent(String($1), isDirectory: true)
        }.standardizedFileURL
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectoryValue: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryValue)
            && isDirectoryValue.boolValue
    }
}
