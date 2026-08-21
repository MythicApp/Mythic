//
//  SteamGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import OSLog

/**
 A game owned through Steam and acquired via SteamCMD.

 **Scope.** Mythic acquires Steam titles with SteamCMD, which is a native macOS binary and never touches
 Wine, so download/update/verify work on the current engine. Launching a downloaded Windows title goes
 through Mythic's existing Wine path. What is *not* supported is any title that authenticates through the
 live Steam client at runtime (Steamworks tickets, EOS-over-Steam): the client's Chromium 126 CEF helper
 does not survive on the engine's `wine-7.7`, so such titles download correctly and then fail to launch.
 Raising that ceiling is an `Engine/` concern, not a `Steam/` one.
 */
class SteamGame: Game {
    override var storefront: Storefront? { .steam }

    /**
     Steam's application ID.

     Stored *as* ``Game/id`` rather than as a field of its own. It is the key `app_update`, `app_status`,
     `appmanifest_<appid>.acf` and every CDN artwork URL are all written in terms of, and `id` is the only
     key `GameDataStore`'s merge actually discriminates on. A separate persisted field would also force
     `Game.encode(to:)` out of its extension and into the class body to become overridable, which is
     base-class surgery affecting Epic and Local for no gain here.

     This mirrors `EpicGamesGame`, whose `id` is the legendary app name.
     */
    var appID: String { id }

    // MARK: - Artwork
    //
    // `computedVerticalImageURL`/`computedHorizontalImageURL` are synchronous and non-throwing, and the
    // render site is a bare `AsyncImage` with no cache and no header plumbing. That rules out SteamGridDB
    // here (it needs an API key and an async search); it belongs in a background resolver writing into the
    // persisted `_verticalImageURL`/`_horizontalImageURL` instead. The Steam CDN needs no key.

    private static let contentDeliveryNetwork = "https://cdn.cloudflare.steamstatic.com/steam/apps"

    /// 3:4 grid card.
    override var computedVerticalImageURL: URL? {
        URL(string: "\(Self.contentDeliveryNetwork)/\(appID)/library_600x900_2x.jpg")
    }

    /// 16:9 hero/list card.
    override var computedHorizontalImageURL: URL? {
        URL(string: "\(Self.contentDeliveryNetwork)/\(appID)/header.jpg")
    }

    // MARK: - On-disk state

    /**
     Location of this title's Steam app manifest, if the game is installed.

     SteamCMD invoked with `force_install_dir <dir>` writes game files directly into `<dir>` and the
     manifest to `<dir>/steamapps/appmanifest_<appid>.acf` — verified against a real `app_update` run.
     */
    var appManifestURL: URL? {
        guard case .installed(let location, _) = installationState else { return nil }
        return location
            .appending(path: "steamapps")
            .appending(path: "appmanifest_\(appID).acf")
    }

    /// The parsed manifest, or `nil` if the game is not installed or the manifest is unreadable.
    var appManifest: ValveDataFormat.AppManifest? {
        guard let appManifestURL,
              FileManager.default.fileExists(atPath: appManifestURL.path(percentEncoded: false))
        else { return nil }

        do {
            return try ValveDataFormat.parseAppManifest(contentsOf: appManifestURL)
        } catch {
            Logger.app.warning("Unreadable Steam app manifest for \(self.appID, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }

    override var isUpdateAvailable: Bool? {
        appManifest?.isUpdateAvailable
    }

    /// Whether Steam has flagged this installation's files as missing or corrupt.
    var requiresVerification: Bool {
        appManifest?.requiresVerification ?? false
    }

    // MARK: - Initialisers

    /// - Parameter appID: Steam's application ID; becomes ``Game/id``.
    init(appID: String,
         title: String,
         installationState: InstallationState,
         containerURL: URL? = nil) {
        super.init(id: appID,
                   title: title,
                   installationState: installationState,
                   containerURL: containerURL)
    }

    override init(id: String = UUID().uuidString,
                  title: String,
                  installationState: InstallationState,
                  containerURL: URL? = nil) {
        super.init(id: id,
                   title: title,
                   installationState: installationState,
                   containerURL: containerURL)
    }

    required init(from decoder: any Decoder) throws {
        // super.init(from:) handles all decoding including subclass routing
        // say 'thank you, super.init❤️'
        try super.init(from: decoder)
    }

    // MARK: - Operations
    //
    // These forward to SteamGameManager. They are not optional: the base implementations are
    // `fatalError`, and GameCard's Play button calls `game.launch()`, not the manager -- so omitting
    // `_launch()` did not degrade anything, it killed the app the first time anyone pressed Play on an
    // installed Steam title.

    override func _launch() async throws {
        try await SteamGameManager.launch(steamGame: self)
    }

    override func _update() async throws {
        try await SteamGameManager.update(steamGame: self, atQualityOfService: .default)
    }

    override func _move(from currentLocation: URL, to newLocation: URL) async throws {
        try await SteamGameManager.move(steamGame: self, toLocation: newLocation)
    }

    /// Steam has no separate repair verb; `app_update … validate` re-hashes and refetches what differs.
    override func _verifyInstallation() async throws {
        try await SteamGameManager.repair(steamGame: self, atQualityOfService: .default)
    }

    override func getSupportedPlatforms() -> Set<Game.Platform>? {
        Steam.cachedAppInfo(appID: appID).map(Steam.supportedPlatforms(for:))
    }
}
