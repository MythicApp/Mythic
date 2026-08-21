//
//  SteamInterface.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import OSLog

/**
 The storefront-service surface for Steam — the peer of `Legendary` for Epic.

 Everything here runs through ``SteamCMD``, which is a native macOS binary, so none of it depends on
 Mythic Engine. What it cannot do is anything requiring the Steam GUI client; see ``SteamGame``.
 */
final class Steam {
    static let log: Logger = .custom(category: "steam")

    // MARK: - Errors

    struct NotSignedInError: LocalizedError {
        var errorDescription: String? = String(localized: "You aren't signed in to Steam.")
    }

    struct UnknownAppError: LocalizedError {
        let appID: String
        var errorDescription: String? {
            String(localized: "Steam didn't recognise app \(appID).")
        }
    }

    // MARK: - Install location
    //
    // Board item: "Custom install directory".

    /// Where Steam titles are installed. Falls back to Mythic's shared install base, then to Documents.
    static var installBaseURL: URL {
        if let custom = UserDefaults.standard.url(forKey: "steamInstallBaseURL") {
            return custom
        }
        if let shared = UserDefaults.standard.url(forKey: "installBaseURL") {
            return shared.appending(path: "Steam")
        }
        return FileLocations.globalGames ?? .documentsDirectory.appending(path: "Mythic/Steam")
    }

    /**
     Install location for a single title.

     One `force_install_dir` per game, named by appid. SteamCMD writes the app's manifest to
     `<dir>/steamapps/appmanifest_<appid>.acf` — which is exactly where ``SteamGame/appManifestURL``
     looks — so a per-game directory keeps discovery and state reading symmetrical. The appid rather
     than the title also means the path never has to be renamed or escaped.
     */
    static func installURL(forAppID appID: String) -> URL {
        installBaseURL.appending(path: appID)
    }

    /// Forced platform for downloads, as chosen in Settings.
    static var forcedPlatform: SteamCMD.ForcedPlatform {
        UserDefaults.standard.string(forKey: "steamForcedPlatform")
            .flatMap(SteamCMD.ForcedPlatform.init(rawValue:)) ?? .windows
    }

    // MARK: - Account
    //
    // Board item: "Functional signin + steam guard support".

    private static var steamRootURL: URL {
        SteamCMD.homeDirectory.appending(path: "Library/Application Support/Steam")
    }

    private static var loginUsersURL: URL {
        steamRootURL.appending(path: "config/loginusers.vdf")
    }

    /**
     Whether SteamCMD holds a cached session for a real (non-anonymous) account.

     Verified against an actual sign-in, which corrected an earlier assumption: SteamCMD does **not**
     write `config/loginusers.vdf` — that is the desktop client's file, and it stays absent even after a
     fully successful login. What SteamCMD does write is `userdata/<accountid>/`, using
     `userdata/anonymous/` for anonymous sessions. A numerically-named directory there is therefore the
     signal, and a stored username alone is not: that would keep claiming a session long after one
     lapsed.
     */
    static var hasCachedSession: Bool {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            atPath: steamRootURL.appending(path: "userdata").path(percentEncoded: false)
        ) else { return false }

        return entries.contains { UInt64($0) != nil }
    }

    /**
     The Steam account SteamCMD currently has a cached session for.

     Primary source is `config/loginusers.vdf`, which survives Mythic's own preferences being reset.
     The username Mythic signed in with is kept as a fallback, because a fresh SteamCMD that has only
     ever logged in anonymously writes no `loginusers.vdf` at all (verified — an anonymous run produces
     `config.vdf`, `libraryfolders.vdf` and `userdata/anonymous/`, and nothing else).

     - Note: the `loginusers.vdf` shape below follows Valve's documented layout. It could not be
       exercised here, since doing so needs real Steam credentials.
     */
    /**
     The account name to hand `+login`, or `nil` if it is not known.

     Deliberately separate from ``retrieveUser()``: that one may return a placeholder so the Accounts card
     has something to show, and feeding a placeholder to `+login` would fail every SteamCMD run.
     */
    static var cachedAccountName: String? {
        guard hasCachedSession else { return nil }

        if let parsed = try? ValveDataFormat.parse(contentsOf: loginUsersURL),
           let users = parsed[caseInsensitive: "users"]?.objectValue {
            let accounts: [(name: String, isMostRecent: Bool)] = users.values.compactMap { user in
                guard let name = user["AccountName"]?.stringValue else { return nil }
                return (name: name, isMostRecent: user["MostRecent"]?.stringValue == "1")
            }

            if let mostRecent = accounts.first(where: \.isMostRecent) { return mostRecent.name }
            if let first = accounts.first { return first.name }
        }

        return UserDefaults.standard.string(forKey: "steamUsername")
    }

    static func retrieveUser() -> String? {
        guard hasCachedSession else { return nil }

        if let parsed = try? ValveDataFormat.parse(contentsOf: loginUsersURL),
           let users = parsed[caseInsensitive: "users"]?.objectValue {
            // Prefer the account flagged MostRecent; otherwise any account present.
            let accounts: [(name: String, isMostRecent: Bool)] = users.values.compactMap { user in
                guard let name = user["AccountName"]?.stringValue else { return nil }
                return (name: name, isMostRecent: user["MostRecent"]?.stringValue == "1")
            }

            if let mostRecent = accounts.first(where: \.isMostRecent) { return mostRecent.name }
            if let first = accounts.first { return first.name }
        }

        return UserDefaults.standard.string(forKey: "steamUsername")
            ?? String(localized: "Steam user")
    }

    /**
     Whether Mythic can actually act as the signed-in user.

     Requires a usable account name, not merely a cached session on disk: every SteamCMD run needs one for
     `+login`, and a session we cannot name is a session we cannot use. Reporting it as signed in would
     silently downgrade every subsequent run to anonymous, where `licenses_print` returns nothing at all —
     so a library that looked empty would really be a login Mythic could not address.
     */
    static var isSignedIn: Bool { cachedAccountName != nil }

    /// What the sign-in flow is currently waiting on, for the UI to relay.
    enum SignInStatus: Sendable {
        case connecting
        /// Steam has pushed a confirmation to the Steam Mobile App and is waiting for approval.
        case awaitingMobileConfirmation
    }

    /**
     Signs in to Steam through SteamCMD.

     - Parameter steamGuardCode: an emailed Steam Guard code or a mobile authenticator code. Pass `nil`
       on the first attempt; if the account needs one, this throws ``SteamCMD/Failure/twoFactorRequired``
       and the caller should ask for a code and retry.
     - Returns: the signed-in account name.
     */
    @discardableResult
    static func signIn(username: String,
                       password: String,
                       steamGuardCode: String? = nil,
                       onStatus: (@Sendable (SignInStatus) -> Void)? = nil) async throws -> String {
        let credentials: SteamCMD.Credentials = .init(username: username,
                                                      password: password,
                                                      steamGuardCode: steamGuardCode)

        // No commands: `+login` alone is enough to establish and cache the session.
        // requiresSuccessfulLogin makes a timed-out mobile confirmation an error rather than a silent
        // "success" that writes a username Mythic has no session for.
        try await SteamCMD.run(commands: [],
                               credentials: credentials,
                               forcedPlatform: nil,
                               requiresSuccessfulLogin: true) { line in
            switch line {
            case .awaitingMobileConfirmation: onStatus?(.awaitingMobileConfirmation)
            case .loginInProgress:            onStatus?(.connecting)
            default:                          break
            }
        }

        UserDefaults.standard.set(username, forKey: "steamUsername")

        // A refresh failure must not invalidate an otherwise successful sign-in.
        try? await GameDataStore.shared.refreshFromStorefronts(.steam)

        return username
    }

    static func signOut() async throws {
        if SteamCMD.isInstalled {
            // Best-effort: the local session files are removed regardless of whether SteamCMD cooperates.
            try? await SteamCMD.run(commands: [.raw("logout")], forcedPlatform: nil)
        }

        try? FileManager.default.removeItemIfExists(at: loginUsersURL)
        UserDefaults.standard.removeObject(forKey: "steamUsername")
    }

    // MARK: - Library
    //
    // Board item: "Fetch game list".

    /**
     Every Steam title installed under ``installBaseURL``.

     Discovery is by on-disk manifest rather than by asking SteamCMD, because it must be synchronous:
     `StorefrontGameManager.fetchUpdateAvailability(for:)` and `isFileVerificationRequired(for:)` are
     sync and throwing and cannot shell out.
     */
    static func getInstalledGames() throws -> [SteamGame] {
        let fileManager: FileManager = .default
        guard fileManager.fileExists(atPath: installBaseURL.path(percentEncoded: false)) else { return [] }

        let entries = try fileManager.contentsOfDirectory(
            at: installBaseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return entries.compactMap { entry -> SteamGame? in
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }

            let steamAppsURL = entry.appending(path: "steamapps")
            guard let manifests = try? fileManager.contentsOfDirectory(atPath: steamAppsURL.path(percentEncoded: false)) else {
                return nil
            }

            guard let manifestName = manifests.first(where: {
                $0.hasPrefix("appmanifest_") && $0.hasSuffix(".acf")
            }) else { return nil }

            // `try?` already flattens the double optional here.
            guard let manifest = try? ValveDataFormat.parseAppManifest(
                contentsOf: steamAppsURL.appending(path: manifestName)
            ) else { return nil }

            // Steam records the platform nowhere in the manifest, so it is inferred from what the depot
            // actually produced: a .app bundle means the macOS build, anything else the Windows one.
            let platform: Game.Platform = fileManager.fileExists(
                atPath: entry.appending(path: "\(manifest.installDirectoryName ?? "").app").path(percentEncoded: false)
            ) ? .macOS : .windows

            return SteamGame(
                appID: manifest.appID,
                title: manifest.name ?? manifest.appID,
                installationState: .installed(location: entry, platform: platform)
            )
        }
    }

    /**
     Titles the account owns but has not installed.

     Read from a cache Mythic maintains itself, because this is synchronous by protocol. That mirrors
     Epic, where the equivalent list comes from JSON that legendary has already written; here Mythic is
     the thing that writes it, in ``refreshOwnedGames(force:)``.
     */
    static func getInstallableGames() throws -> [SteamGame] {
        guard isSignedIn else { throw NotSignedInError() }

        return (try? loadOwnedGames())?.games.map {
            SteamGame(appID: $0.appID, title: $0.name, installationState: .uninstalled)
        } ?? []
    }

    // MARK: - Owned library
    //
    // Board item: "Fetch game list".

    struct OwnedGamesCache: Codable {
        var refreshedAt: Date
        var games: [OwnedGame]
    }

    private static var ownedGamesCacheURL: URL {
        SteamCMD.directory.appending(path: "library.json")
    }

    private static func loadOwnedGames() throws -> OwnedGamesCache {
        try JSONDecoder().decode(OwnedGamesCache.self,
                                 from: try Data(contentsOf: ownedGamesCacheURL))
    }

    /// How long an enumeration is trusted before it is worth redoing. Licences change rarely, and the
    /// refresh costs a SteamCMD session plus a metadata pass over the whole library.
    private static let ownedGamesCacheLifetime: TimeInterval = 6 * 60 * 60

    /**
     Enumerates the account's library and caches it.

     There is no single command for this, so it is assembled:

     1. `licenses_print` lists every package the account holds, with the app IDs in each. Steam caps how
        many it prints per package and says so (`(N in total)`), so any package that printed fewer than it
        claims is read again through `package_info_print`, which lists them all. Measured on a real
        account: 113 packages, 284 app IDs printed, 455 claimed — 171 of them behind a single elided line.
     2. `app_info_print` resolves each ID to a name and a type. The type matters: without it a library
        fills up with DLC, soundtracks, demos and dedicated servers. Batched, because one SteamCMD session
        costs seconds of bootstrap and login regardless of how many commands it carries.

     Package 0 is skipped. It is Steam's default package — 196 entries of Valve internals and
     free-for-everyone apps on the account measured — and anything genuinely owned also appears under a
     real licence.
     */
    /// Coarse stages of an enumeration, for a caller that wants to show progress.
    enum LibraryRefreshStage: Sendable, Equatable {
        case readingLicences
        /// `completed` of `total` metadata batches done.
        case resolvingTitles(completed: Int, total: Int, titleCount: Int)
        case finished(gameCount: Int)
    }

    /**
     Collapses concurrent enumerations into one.

     `refreshFromStorefronts` legitimately gets called more than once at launch — the empty library view
     asks for one, and so does the app delegate. Serialising the underlying SteamCMD runs stops them
     corrupting each other, but without this the second caller would still redo the whole minute-long pass
     for nothing.
     */
    private actor RefreshCoordinator {
        static let shared = RefreshCoordinator()

        private var inFlight: Task<Void, Error>?

        func run(_ operation: @Sendable @escaping () async throws -> Void) async throws {
            if let inFlight { return try await inFlight.value }

            let task = Task { try await operation() }
            inFlight = task

            defer { inFlight = nil }
            try await task.value
        }
    }

    static func refreshOwnedGames(
        force: Bool = false,
        onStage: (@Sendable (LibraryRefreshStage) -> Void)? = nil
    ) async throws {
        try await RefreshCoordinator.shared.run {
            try await performOwnedGamesRefresh(force: force, onStage: onStage)
        }
    }

    private static func performOwnedGamesRefresh(
        force: Bool,
        onStage: (@Sendable (LibraryRefreshStage) -> Void)?
    ) async throws {
        guard isSignedIn else { throw NotSignedInError() }

        if !force,
           let cache = try? loadOwnedGames(),
           Date.now.timeIntervalSince(cache.refreshedAt) < ownedGamesCacheLifetime {
            return
        }

        onStage?(.readingLicences)
        let appIDs = try await fetchOwnedAppIDs()
        log.notice("Steam library: \(appIDs.count, privacy: .public) owned app IDs to resolve")

        var games: [OwnedGamesCache.OwnedGame] = .init()

        // 50 keeps a single batch's output to a few thousand lines while still amortising bootstrap.
        let batches = appIDs.chunked(into: 50)
        onStage?(.resolvingTitles(completed: 0, total: batches.count, titleCount: appIDs.count))

        for (index, batch) in batches.enumerated() {
            // capture, not run: this output *is* the result, and streamed chunks arrive split mid-line.
            let output = try await SteamCMD.capture(
                commands: batch.map { SteamCMD.Command.appInfoPrint(appID: $0) },
                credentials: metadataCredentials,
                // One unrecognised app ID would otherwise abandon the rest of the batch.
                stopOnFailedCommand: false
            )
            for appID in batch {
                guard let info = ValveDataFormat.parseAppInfo(appID: appID, from: output) else { continue }
                guard info.isGame else { continue }

                games.append(.init(appID: info.appID, name: info.name))
                cacheAppInfoBlock(appID: appID, from: output)
            }

            onStage?(.resolvingTitles(completed: index + 1,
                                      total: batches.count,
                                      titleCount: appIDs.count))
        }

        let cache = OwnedGamesCache(refreshedAt: .now, games: games.sorted { $0.name < $1.name })
        try JSONEncoder().encode(cache).write(to: ownedGamesCacheURL, options: .atomic)

        log.notice("Steam library: \(games.count, privacy: .public) games cached")
        onStage?(.finished(gameCount: games.count))
    }

    /// Every app ID the account holds a licence for, package 0 excluded.
    private static func fetchOwnedAppIDs() async throws -> [String] {
        let licences = try await SteamCMD.capture(commands: [.licensesPrint],
                                                  credentials: metadataCredentials)

        let packages = ValveDataFormat.parseLicenses(from: licences)
            .filter { $0.packageID != "0" }

        var appIDs: [String] = packages.flatMap(\.listedAppIDs)

        let truncated = packages.filter(\.isTruncated)
        if !truncated.isEmpty {
            let packageOutput = try await SteamCMD.capture(
                commands: truncated.map { SteamCMD.Command.packageInfoPrint(packageID: $0.packageID) },
                credentials: metadataCredentials
            )

            for package in truncated {
                appIDs += ValveDataFormat.parsePackageAppIDs(packageID: package.packageID,
                                                             from: packageOutput)
            }
        }

        // Order-preserving deduplication.
        var seen: Set<String> = .init()
        return appIDs.filter { seen.insert($0).inserted }
    }

    /// Saves one app's block out of a batch transcript, so launching does not have to re-fetch it.
    private static func cacheAppInfoBlock(appID: String, from output: String) {
        guard let block = ValveDataFormat.isolateBlock(id: appID, from: output) else { return }

        do {
            try FileManager.default.createDirectory(at: appInfoCacheDirectory, withIntermediateDirectories: true)
            try block.write(to: appInfoCacheURL(appID: appID), atomically: true, encoding: .utf8)
        } catch {
            log.warning("Couldn't cache app info for \(appID, privacy: .public): \(error.localizedDescription)")
        }
    }

    /// `+login` for a SteamCMD run that only needs metadata: reuse the cached session if there is one,
    /// otherwise go anonymous. Passing no credentials at all would skip `+login` entirely and leave the
    /// run unauthenticated.
    private static var metadataCredentials: SteamCMD.Credentials {
        if let accountName = cachedAccountName { return .init(username: accountName) }
        return .anonymous
    }

    // MARK: - App info, with an on-disk cache
    //
    // The cache exists because launching needs the executable name, which lives in `config/launch` and
    // nowhere on disk after install. A SteamCMD round trip costs seconds (it re-checks for its own
    // update every run), so the raw blob is kept beside SteamCMD and re-read synchronously. Caching a
    // sidecar file rather than adding a persisted field to `SteamGame` keeps `Game.encode(to:)` in its
    // extension -- see the plan's design note on why that matters.

    private static var appInfoCacheDirectory: URL {
        SteamCMD.directory.appending(path: "appinfo")
    }

    private static func appInfoCacheURL(appID: String) -> URL {
        appInfoCacheDirectory.appending(path: "\(appID).vdf")
    }

    /// Parsed `app_info_print` blob from the cache, if one has been fetched before.
    static func cachedAppInfo(appID: String) -> ValveDataFormat.AppInfo? {
        guard let raw = try? String(contentsOf: appInfoCacheURL(appID: appID), encoding: .utf8) else {
            return nil
        }
        return ValveDataFormat.parseAppInfo(appID: appID, from: raw)
    }

    /// Cached info if available, otherwise fetched and cached.
    static func appInfo(appID: String) async throws -> ValveDataFormat.AppInfo {
        if let cached = cachedAppInfo(appID: appID) { return cached }
        return try await refreshAppInfo(appID: appID)
    }

    /// Fetches `app_info_print` output, caches the raw blob, and returns the parsed result.
    @discardableResult
    static func refreshAppInfo(appID: String) async throws -> ValveDataFormat.AppInfo {
        let raw = try await SteamCMD.capture(commands: [.appInfoPrint(appID: appID)],
                                             credentials: metadataCredentials)
        guard let info = ValveDataFormat.parseAppInfo(appID: appID, from: raw) else {
            throw UnknownAppError(appID: appID)
        }

        do {
            try FileManager.default.createDirectory(at: appInfoCacheDirectory, withIntermediateDirectories: true)
            try raw.write(to: appInfoCacheURL(appID: appID), atomically: true, encoding: .utf8)
        } catch {
            // A cache write failure costs a slower launch, not correctness.
            log.warning("Couldn't cache app info for \(appID, privacy: .public): \(error.localizedDescription)")
        }

        return info
    }

    /// Maps `common/oslist` onto Mythic's platform type.
    static func supportedPlatforms(for info: ValveDataFormat.AppInfo) -> Set<Game.Platform> {
        var platforms: Set<Game.Platform> = .init()
        if info.operatingSystems.contains("windows") { platforms.insert(.windows) }
        if info.operatingSystems.contains("macos") { platforms.insert(.macOS) }
        return platforms
    }
}

private extension Array {
    /// Splits into batches of at most `size`. Used to keep a single SteamCMD metadata run's output
    /// bounded while still amortising its bootstrap and login cost over many commands.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Steam.OwnedGamesCache {
    struct OwnedGame: Codable {
        var appID: String
        var name: String
    }
}
