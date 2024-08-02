//
//  DatabaseData.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 7/31/24.
//

import Foundation

/// Stores Mythic's Data
@MainActor
public final class DatabaseData: ObservableObject, Sendable {
    /// Singleton
    public static let shared = DatabaseData()

    /// MythicConfigData.json
    private static let dbFileName = Bundle.appHome?
        .appendingPathComponent("MythicConfigData.json")
    
    /// Engine Release Stream.
    public enum EngineReleaseStream: String, Codable, Hashable {
        case stable
        case experimental
    }
    
    /// Library Display Mode
    public enum LibraryDisplayMode: String, Codable, Hashable {
        case list
        case grid
    }

    /// App data.
    public struct AppData: Codable, Hashable, Equatable {
        /// Onboarding
        public var hasCompletedOnboarding: Bool
        /// Engine release stream
        public var engineReleaseStream: EngineReleaseStream
        /// Auto check for engine updates
        public var engineUpdatesAutoCheck: Bool
        
        /// Library Display Mode
        public var libraryDisplayMode: LibraryDisplayMode
        
        /// Hide the Mythic client when games launch
        public var hideMythicOnGameLaunch: Bool
        /// Close games opened with Mythic when Mythic closes
        public var closeGamesWithMythic: Bool
        /// Enable Discord RPC
        public var enableDiscordRPC: Bool
        /// Installation path for games
        public var gameInstallPath: URL

        /// All coding keys
        private enum CodingKeys: String, CodingKey {
            // swiftlint:disable:previous nesting
            case hasCompletedOnboarding
            case engineReleaseStream
            case engineUpdatesAutoCheck
            case libraryDisplayMode
            case hideMythicOnGameLaunch
            case closeGamesWithMythic
            case enableDiscordRPC
            case gameInstallPath
        }

        /// Default values
        public init() {
            // Default values
            hasCompletedOnboarding = false
            engineReleaseStream = .stable
            engineUpdatesAutoCheck = true
            libraryDisplayMode = .grid
            hideMythicOnGameLaunch = false
            closeGamesWithMythic = false
            enableDiscordRPC = true
            gameInstallPath = Bundle.appGames ?? .init(filePath: "")
        }

        /// Decoding (safely)
        public init(from decoder: Decoder) throws {
            let defaultValues = AppData()

            // For each key, if it's missing, use the default value.
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Actually decode the values
            hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaultValues.hasCompletedOnboarding
            engineReleaseStream = try container.decodeIfPresent(EngineReleaseStream.self, forKey: .engineReleaseStream) ?? defaultValues.engineReleaseStream
            engineUpdatesAutoCheck = try container.decodeIfPresent(Bool.self, forKey: .engineUpdatesAutoCheck) ?? defaultValues.engineUpdatesAutoCheck
            libraryDisplayMode = try container.decodeIfPresent(LibraryDisplayMode.self, forKey: .libraryDisplayMode) ?? defaultValues.libraryDisplayMode
            hideMythicOnGameLaunch = try container.decodeIfPresent(Bool.self, forKey: .hideMythicOnGameLaunch) ?? defaultValues.hideMythicOnGameLaunch
            closeGamesWithMythic = try container.decodeIfPresent(Bool.self, forKey: .closeGamesWithMythic) ?? defaultValues.closeGamesWithMythic
            enableDiscordRPC = try container.decodeIfPresent(Bool.self, forKey: .enableDiscordRPC) ?? defaultValues.enableDiscordRPC
            gameInstallPath = try container.decodeIfPresent(URL.self, forKey: .gameInstallPath) ?? defaultValues.gameInstallPath
        }
        
    }

    /// Database data
    @Published public var data: AppData {
        didSet {
            save(data: data)
        }
    }

    /// Initialize the config.
    private init() {
        data = DatabaseData.load()
    }

    /// Load the config.
    private static func load() -> AppData {
        guard let dbFileName = DatabaseData.dbFileName else {
            return AppData()
        }

        guard let data = try? Data(contentsOf: dbFileName) else {
            return AppData()
        }

        guard let decoded = try? JSONDecoder().decode(AppData.self, from: data) else {
            return AppData()
        }

        return decoded
    }

    /// Save the config.
    private func save(data: AppData) {
        guard let dbFileName = DatabaseData.dbFileName else {
            return
        }

        // Create the File
        if !FileManager.default.fileExists(atPath: dbFileName.path) {
            try? FileManager.default.createDirectory(
                at: dbFileName.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: nil)
            FileManager.default.createFile(atPath: dbFileName.path(), contents: "".data(using: .utf8))
        }

        guard let encoded = try? JSONEncoder().encode(data) else {
            return
        }
        
        try? encoded.write(to: dbFileName)
    }
}
