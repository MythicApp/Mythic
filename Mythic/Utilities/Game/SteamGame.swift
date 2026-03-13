//
//  SteamGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 15/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

class SteamGame: Game {
    enum CodingKeys: String, CodingKey {
        case steamInstallationRootURL
    }
    
    struct InstallationSource: Hashable {
        let rootURL: URL
        let containerURL: URL?
    }
    
    override var storefront: Storefront? { .steam }
    override var supportsLaunching: Bool { SteamGameManager.canLaunch(game: self) }
    override var computedVerticalImageURL: URL? {
        Steam.artworkURL(forAppID: id, kind: .verticalLibraryCapsule)
    }
    override var computedHorizontalImageURL: URL? {
        Steam.artworkURL(forAppID: id, kind: .horizontalLibraryHero)
    }
    
    var steamInstallationRootURL: URL?
    
    var installationSource: InstallationSource? {
        guard let steamInstallationRootURL else { return nil }
    
        let normalizedRootURL = steamInstallationRootURL.standardizedFileURL
        let importedContainerURL: URL? = _containerURL.flatMap { candidate -> URL? in
            let normalizedContainerURL = candidate.standardizedFileURL
            guard normalizedRootURL.path.hasPrefix(normalizedContainerURL.path) else { return nil }
            return normalizedContainerURL
        }
    
        return .init(rootURL: normalizedRootURL, containerURL: importedContainerURL)
    }
    
    init(manifest: Steam.AppManifest, steamInstallationRootURL: URL, containerURL: URL? = nil) {
        self.steamInstallationRootURL = steamInstallationRootURL.standardizedFileURL
        
        // Steam manifests do not expose enough metadata to distinguish Windows installs
        // from other platform builds. Imported Steam support in Mythic targets existing
        // Windows Steam libraries inside Wine containers, so these installs are modelled
        // as Windows games.
        super.init(id: manifest.appID,
                   title: manifest.name,
                   installationState: .installed(location: manifest.installationURL, platform: .windows),
                   containerURL: containerURL)
    }
    
    override init(id: String = UUID().uuidString,
                  title: String,
                  installationState: InstallationState,
                  containerURL: URL? = nil) {
        self.steamInstallationRootURL = nil
        super.init(id: id,
                   title: title,
                   installationState: installationState,
                   containerURL: containerURL)
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.steamInstallationRootURL = try container.decodeIfPresent(URL.self, forKey: .steamInstallationRootURL)?.standardizedFileURL
        
        // super.init(from:) handles all Game decoding, while SteamGame restores its
        // installation root so refresh and launch can keep using the same Steam client.
        try super.init(from: decoder)
    }
    
    override func encode(to encoder: any Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(steamInstallationRootURL, forKey: .steamInstallationRootURL)
    }
    
    override func _launch() async throws {
        try await SteamGameManager.launch(game: self)
    }
    
    override func _update() async throws {
        throw UnsupportedOperationError(operation: "Updating",
                                        game: self,
                                        reason: "Steam update integration is not implemented yet.")
    }
    
    override func _move(from currentLocation: URL,
                        to newLocation: URL) async throws {
        throw UnsupportedOperationError(operation: "Moving",
                                        game: self,
                                        reason: "Steam library relocation is not implemented yet.")
    }
    
    override func _verifyInstallation() async throws {
        throw UnsupportedOperationError(operation: "Verifying file integrity",
                                        game: self,
                                        reason: "Steam verification is not implemented yet.")
    }
}
