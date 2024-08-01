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
        public var hasCompletedOnboarding: Bool = false
        // Engine release stream
        public var engineReleaseStream: EngineReleaseStream = .stable
        
        /// Library Display Mode
        public var libraryDisplayMode: LibraryDisplayMode = .grid
        
        /// Hide the Mythic client when games launch
        public var hideMythicOnGameLaunch: Bool = false
        /// Close games opened with Mythic when Mythic closes
        public var closeGamesWithMythic: Bool = false
        /// Enable Discord RPC
        public var enableDiscordRPC: Bool = true
        /// Installation path for games
        public var gameInstallPath: URL = Bundle.appGames ?? .init(filePath: "")
        
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
