//
//  AppSettingsV1PersistentStateModel.swift
//  Mythic
//

import Foundation

public struct AppSettingsV1PersistentStateModel: StorablePersistentStateModel.State {
    /// Shared instance.
    @MainActor public static let shared: StorablePersistentStateModel.Store<Self> = .init()

    public typealias RootType = AppSettings
    public static let persistentStateStoreName = "AppSettingsV1"

    public static func defaultValue() -> AppSettings {
        .init()
    }

    /// Auto update settings.
    public enum AutoUpdateAction: String, Codable, Hashable {
        case off
        case check
        case install
    }

    /// The app settings.
    public struct AppSettings: Codable, Hashable, Equatable {
        /// The default game storage directory.
        public static let defaultGameStorageDirectory: URL? = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first?
            .appendingPathComponent("Games")
            .appendingPathComponent("Mythic")

        /// Telemetry settings.
        public var enableTelemetry: Bool = true

        /// Sparkle update action.
        public var sparkleUpdateAction: AutoUpdateAction = .check

        /// Onboarding status.
        public var inOnboarding: Bool = true

        /// Engine release branch.
        public var engineReleaseBranch: EngineVersionsDownloadModel.ReleaseBranch = .stable
        /// Engine update action.
        public var engineUpdateAction: AutoUpdateAction = .check

        /// Hide the main window on game launch.
        public var hideOnGameLaunch: Bool = false
        /// Close opened games on quit.
        public var closeGamesOnQuit: Bool = false

        /// Enable discord rich presence while browsing.
        public var enableDiscordRichPresence: Bool = true

        /// Where games are stored.
        public var gameStorageDirectory: URL = AppSettings.defaultGameStorageDirectory ?? FileManager.default.temporaryDirectory
    }
}
