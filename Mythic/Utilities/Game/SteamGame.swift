//
//  SteamGame.swift
//  Mythic
//

import AppKit
import Foundation

class SteamGame: Game {
    override var storefront: Storefront? { .steam }

    var appID: String? { SteamClient.appID(fromGameID: id) }

    convenience init?(appID: String,
                     title: String,
                     installationState: InstallationState,
                     containerURL: URL? = nil) {
        guard let gameID = SteamClient.gameID(forAppID: appID) else { return nil }
        self.init(id: gameID, title: title, installationState: installationState, containerURL: containerURL)
    }

    override var computedVerticalImageURL: URL? {
        guard let appID else { return nil }
        return SteamClient.imageURL(appID: appID, vertical: true)
    }

    override var computedHorizontalImageURL: URL? {
        guard let appID else { return nil }
        return SteamClient.imageURL(appID: appID, vertical: false)
    }

    override func getSupportedPlatforms() -> Set<Game.Platform>? {
        guard let appID,
              let installedApp = SteamClient.installedApp(appID: appID) else {
            return nil
        }
        return [installedApp.location.platform]
    }

    override var isUpdateAvailable: Bool? {
        guard let appID else { return nil }
        return SteamClient.installedApp(appID: appID)?.isUpdateRequired
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
        try super.init(from: decoder)
    }

    override func _checkIfGameIsRunning(location: URL, platform: Platform) -> Bool {
        guard case .macOS = platform else { return false }
        let installPath = location.standardizedFileURL.resolvingSymlinksInPath().path
        let installPrefix = installPath.hasSuffix("/") ? installPath : installPath + "/"
        return NSWorkspace.shared.runningApplications.contains { application in
            guard let bundleURL = application.bundleURL else { return false }
            return bundleURL.standardizedFileURL
                .resolvingSymlinksInPath()
                .path
                .hasPrefix(installPrefix)
        }
    }

    nonisolated override func _launch() async throws {
        try await SteamGameManager.launch(game: self)
    }

    nonisolated override func _update() async throws {
        try await SteamGameManager.update(game: self, qualityOfService: .default)
    }

    nonisolated override func _move(from currentLocation: URL, to newLocation: URL) async throws {
        try await SteamGameManager.move(game: self, to: newLocation)
    }

    nonisolated override func _verifyInstallation() async throws {
        try await SteamGameManager.repair(game: self, qualityOfService: .default)
    }
}
