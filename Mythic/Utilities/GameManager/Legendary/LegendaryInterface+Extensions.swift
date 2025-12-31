//
//  LegendaryInterface+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/10/2023.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation

// swiftlint:disable nesting
extension Legendary {
    // MARK: - aliases.json
    /// A dictionary mapping game IDs to their list of aliases.
    /// Each key is a game identifier (app_name), and the value is an array of alias strings
    /// that can be used to reference that game.
    /// **File:** `aliases.json`
    typealias Aliases = [String: [String]]

    // MARK: - assets.json
    /// Root structure containing platform-specific assets.
    /// Contains arrays of available game assets for different platforms.
    /// **File:** `assets.json`
    struct Assets: Codable {
        /// Available assets for macOS platform
        let mac: [Asset]?
        /// Available assets for Windows platform
        let windows: [Asset]?

        enum CodingKeys: String, CodingKey {
            case mac = "Mac"
            case windows = "Windows"
        }
    }

    /// Represents a game asset (build) for a specific platform.
    /// Contains all information needed to download and install a game build.
    /// **File:** `assets.json`
    struct Asset: Codable {
        /// Application identifier
        let appName: String
        /// Asset identifier (usually same as appName)
        let assetID: String
        /// Build version string
        let buildVersion: String
        /// Catalog item identifier in the Epic Games Store
        let catalogItemID: String
        /// Label name indicating platform and environment (e.g., "Live-Mac", "Live-Windows")
        let labelName: String
        /// Additional metadata for the asset
        let metadata: AssetMetadata
        /// Namespace identifier for the game
        let namespace: String
        /// Sidecar revision number
        let sidecarRev: Int?

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case assetID = "asset_id"
            case buildVersion = "build_version"
            case catalogItemID = "catalog_item_id"
            case labelName = "label_name"
            case metadata
            case namespace
            case sidecarRev = "sidecar_rev"
        }
    }

    /// Metadata associated with an asset.
    /// Contains optional installation and update information.
    /// **File:** `assets.json`
    struct AssetMetadata: Codable {
        /// Installation pool identifier
        let installationPoolID: String?
        /// Type of update (e.g., "MINOR", "PATCH", "MAJOR")
        let updateType: String?

        enum CodingKeys: String, CodingKey {
            case installationPoolID = "installationPoolId"
            case updateType = "update_type"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            installationPoolID = try container.decodeIfPresent(String.self, forKey: .installationPoolID)
            updateType = try container.decodeIfPresent(String.self, forKey: .updateType)
        }
    }

    // MARK: - installed.json
    /// A dictionary mapping app names to their installation details.
    /// Each key is an app_name and the value contains complete installation information.
    /// **File:** `installed.json`
    typealias Installed = [String: InstalledGame]

    /// Prerequisite installer information for a game.
    /// Contains details about DirectX, VC++ redistributables, or other prerequisites.
    /// **File:** `installed.json`
    struct PrereqInfo: Codable {
        /// Prerequisite arguments for installation
        let args: String?
        /// Prerequisite identifiers
        let ids: [String]?
        /// Whether the prerequisite has been installed
        let installed: Bool?
        /// Human-readable name of the prerequisite
        let name: String?
        /// Path to the prerequisite installer relative to game directory
        let path: String?

        enum CodingKeys: String, CodingKey {
            case args
            case ids
            case installed
            case name
            case path
        }
    }

    /// Uninstaller information for a game.
    /// **File:** `installed.json`
    struct UninstallerInfo: Codable {
        /// Command-line arguments for the uninstaller
        let args: String?
        /// Path to the uninstaller executable relative to game directory
        let path: String?

        enum CodingKeys: String, CodingKey {
            case args
            case path
        }
    }

    /// Represents an installed game with all its configuration.
    /// Contains paths, version info, and installation metadata.
    /// **File:** `installed.json`
    struct InstalledGame: Codable {
        /// Application identifier
        let appName: String
        /// Download base URLs for game files
        let baseURLs: [String]
        /// Whether the game can run without internet connection
        let canRunOffline: Bool
        /// Epic Games Launcher GUID
        let eglGUID: String
        /// Executable path relative to install path
        let executable: String
        /// Full installation directory path
        let installPath: String
        /// Installation size in bytes
        let installSize: Int
        /// Installation tags (usually empty)
        let installTags: [String]
        /// Whether this is DLC content
        let isDLC: Bool
        /// Additional command-line launch parameters
        let launchParameters: String
        /// Path to the manifest file
        let manifestPath: String?
        /// Whether the installation needs verification
        let needsVerification: Bool
        /// Platform identifier (e.g., "Windows", "Mac")
        let _platform: String // swiftlint:disable:this identifier_name
        var platform: Game.Platform? { matchPlatformString(for: _platform) }
        /// Prerequisite installation information (DirectX, VC++ redistributables, etc.)
        let prereqInfo: PrereqInfo?
        /// Whether it requires OT (Online Token)
        let requiresOT: Bool
        /// Path to save files
        let savePath: String?
        /// Human-readable game title
        let title: String
        /// Uninstaller information
        let uninstaller: UninstallerInfo?
        /// Installed version string
        let version: String

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case baseURLs = "base_urls"
            case canRunOffline = "can_run_offline"
            case eglGUID = "egl_guid"
            case executable
            case installPath = "install_path"
            case installSize = "install_size"
            case installTags = "install_tags"
            case isDLC = "is_dlc"
            case launchParameters = "launch_parameters"
            case manifestPath = "manifest_path"
            case needsVerification = "needs_verification"
            case _platform = "platform" // swiftlint:disable:this identifier_name
            case prereqInfo = "prereq_info"
            case requiresOT = "requires_ot"
            case savePath = "save_path"
            case title
            case uninstaller
            case version
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            appName = try container.decode(String.self, forKey: .appName)
            baseURLs = try container.decode([String].self, forKey: .baseURLs)
            canRunOffline = try container.decode(Bool.self, forKey: .canRunOffline)
            eglGUID = try container.decode(String.self, forKey: .eglGUID)
            executable = try container.decode(String.self, forKey: .executable)
            installPath = try container.decode(String.self, forKey: .installPath)
            installSize = try container.decode(Int.self, forKey: .installSize)
            installTags = try container.decode([String].self, forKey: .installTags)
            isDLC = try container.decode(Bool.self, forKey: .isDLC)
            launchParameters = try container.decode(String.self, forKey: .launchParameters)
            manifestPath = try container.decodeIfPresent(String.self, forKey: .manifestPath)
            needsVerification = try container.decode(Bool.self, forKey: .needsVerification)
            _platform = try container.decode(String.self, forKey: ._platform)
            prereqInfo = try container.decodeIfPresent(PrereqInfo.self, forKey: .prereqInfo)
            requiresOT = try container.decode(Bool.self, forKey: .requiresOT)
            savePath = try container.decodeIfPresent(String.self, forKey: .savePath)
            title = try container.decode(String.self, forKey: .title)
            uninstaller = try container.decodeIfPresent(UninstallerInfo.self, forKey: .uninstaller)
            version = try container.decode(String.self, forKey: .version)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(appName, forKey: .appName)
            try container.encode(baseURLs, forKey: .baseURLs)
            try container.encode(canRunOffline, forKey: .canRunOffline)
            try container.encode(eglGUID, forKey: .eglGUID)
            try container.encode(executable, forKey: .executable)
            try container.encode(installPath, forKey: .installPath)
            try container.encode(installSize, forKey: .installSize)
            try container.encode(installTags, forKey: .installTags)
            try container.encode(isDLC, forKey: .isDLC)
            try container.encode(launchParameters, forKey: .launchParameters)
            try container.encodeIfPresent(manifestPath, forKey: .manifestPath)
            try container.encode(needsVerification, forKey: .needsVerification)
            try container.encode(_platform, forKey: ._platform)
            try container.encodeIfPresent(prereqInfo, forKey: .prereqInfo)
            try container.encode(requiresOT, forKey: .requiresOT)
            try container.encodeIfPresent(savePath, forKey: .savePath)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(uninstaller, forKey: .uninstaller)
            try container.encode(version, forKey: .version)
        }
    }

    // MARK: - user.json
    /// User authentication and session data.
    /// Contains OAuth tokens and user profile information for Epic Games services.
    /// **File:** `user.json`
    struct User: Codable {
        /// Access token for authenticated API calls
        let accessToken: String
        /// User's Epic Games account identifier
        let accountID: String
        /// Authentication context class reference
        let acr: String
        /// Application identifier
        let app: String
        /// Authentication timestamp (ISO 8601 format)
        let authTime: Date
        /// OAuth client identifier
        let clientID: String
        /// Client service name (e.g., "launcher")
        let clientService: String
        /// Unique device identifier
        let deviceID: String
        /// User's display name
        let displayName: String
        /// Access token expiration timestamp (ISO 8601 format)
        let expiresAt: Date
        /// Access token expiration duration in seconds
        let expiresIn: Int
        /// In-app user identifier
        let inAppID: String
        /// Whether this is an internal Epic Games client
        let internalClient: Bool
        /// Refresh token expiration duration in seconds
        let refreshExpires: Int
        /// Refresh token expiration timestamp (ISO 8601 format)
        let refreshExpiresAt: Date
        /// Refresh token for obtaining new access tokens
        let refreshToken: String
        /// OAuth scopes granted to this token
        let scope: [String]
        /// Token type (typically "bearer")
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
            case acr
            case app
            case authTime = "auth_time"
            case clientID = "client_id"
            case clientService = "client_service"
            case deviceID = "device_id"
            case displayName
            case expiresAt = "expires_at"
            case expiresIn = "expires_in"
            case inAppID = "in_app_id"
            case internalClient = "internal_client"
            case refreshExpires = "refresh_expires"
            case refreshExpiresAt = "refresh_expires_at"
            case refreshToken = "refresh_token"
            case scope
            case tokenType = "token_type"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            accessToken = try container.decode(String.self, forKey: .accessToken)
            accountID = try container.decode(String.self, forKey: .accountID)
            acr = try container.decode(String.self, forKey: .acr)
            app = try container.decode(String.self, forKey: .app)

            let authTimeString = try container.decode(String.self, forKey: .authTime)
            guard let authTimeDate = dateFormatter.date(from: authTimeString) else {
                throw DecodingError.dataCorruptedError(forKey: .authTime,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            authTime = authTimeDate

            clientID = try container.decode(String.self, forKey: .clientID)
            clientService = try container.decode(String.self, forKey: .clientService)
            deviceID = try container.decode(String.self, forKey: .deviceID)
            displayName = try container.decode(String.self, forKey: .displayName)

            let expiresAtString = try container.decode(String.self, forKey: .expiresAt)
            guard let expiresAtDate = dateFormatter.date(from: expiresAtString) else {
                throw DecodingError.dataCorruptedError(forKey: .expiresAt,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            expiresAt = expiresAtDate

            expiresIn = try container.decode(Int.self, forKey: .expiresIn)
            inAppID = try container.decode(String.self, forKey: .inAppID)
            internalClient = try container.decode(Bool.self, forKey: .internalClient)
            refreshExpires = try container.decode(Int.self, forKey: .refreshExpires)

            let refreshExpiresAtString = try container.decode(String.self, forKey: .refreshExpiresAt)
            guard let refreshExpiresAtDate = dateFormatter.date(from: refreshExpiresAtString) else {
                throw DecodingError.dataCorruptedError(forKey: .refreshExpiresAt,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            refreshExpiresAt = refreshExpiresAtDate

            refreshToken = try container.decode(String.self, forKey: .refreshToken)
            scope = try container.decode([String].self, forKey: .scope)
            tokenType = try container.decode(String.self, forKey: .tokenType)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try container.encode(accessToken, forKey: .accessToken)
            try container.encode(accountID, forKey: .accountID)
            try container.encode(acr, forKey: .acr)
            try container.encode(app, forKey: .app)
            try container.encode(dateFormatter.string(from: authTime), forKey: .authTime)
            try container.encode(clientID, forKey: .clientID)
            try container.encode(clientService, forKey: .clientService)
            try container.encode(deviceID, forKey: .deviceID)
            try container.encode(displayName, forKey: .displayName)
            try container.encode(dateFormatter.string(from: expiresAt), forKey: .expiresAt)
            try container.encode(expiresIn, forKey: .expiresIn)
            try container.encode(inAppID, forKey: .inAppID)
            try container.encode(internalClient, forKey: .internalClient)
            try container.encode(refreshExpires, forKey: .refreshExpires)
            try container.encode(dateFormatter.string(from: refreshExpiresAt), forKey: .refreshExpiresAt)
            try container.encode(refreshToken, forKey: .refreshToken)
            try container.encode(scope, forKey: .scope)
            try container.encode(tokenType, forKey: .tokenType)
        }
    }

    // MARK: - version.json
    /// Root structure for Legendary CLI version and configuration data.
    /// Contains all configuration for game compatibility and CLI settings.
    /// **File:** `version.json`
    struct Version: Codable {
        /// Version data container with all configurations
        let data: VersionData
        /// Last update timestamp (Unix epoch)
        let lastUpdate: Double

        enum CodingKeys: String, CodingKey {
            case data
            case lastUpdate = "last_update"
        }
    }

    /// Version data containing game configurations and overrides.
    /// **File:** `version.json`
    struct VersionData: Codable {
        /// CrossOver bottles configuration for macOS Wine compatibility
        let cxBottles: [CXBottle]
        /// Epic Games Launcher authentication configuration
        let eglConfig: EGLConfig
        /// Game-specific configuration overrides
        let gameOverrides: GameOverrides
        /// Game wiki URLs indexed by game ID and platform
        let gameWiki: [String: GameWikiPlatforms]
        /// Legendary CLI feature flags
        let legendaryConfig: LegendaryConfig
        /// Latest Legendary CLI release information
        let releaseInfo: ReleaseInfo
        /// Runtime dependencies (currently unused)
        let runtimes: [String]

        enum CodingKeys: String, CodingKey {
            case cxBottles = "cx_bottles"
            case eglConfig = "egl_config"
            case gameOverrides = "game_overrides"
            case gameWiki = "game_wiki"
            case legendaryConfig = "legendary_config"
            case releaseInfo = "release_info"
            case runtimes
        }
    }

    /// CrossOver bottle configuration for running Windows games on macOS.
    /// **File:** `version.json`
    struct CXBottle: Codable {
        /// Base URL for downloading bottle files (if different from manifest)
        let baseURL: String?
        /// List of game app IDs compatible with this bottle
        let compatibleApps: [String]
        /// CrossOver system architecture (e.g., "darwin")
        let cxSystem: String
        /// CrossOver version string
        let cxVersion: String
        /// Available CrossOver versions
        let cxVersions: [String]
        /// Human-readable bottle description
        let description: String
        /// Whether this is the default bottle for new installations
        let isDefault: Bool
        /// URL to the bottle manifest file
        let manifest: String
        /// Bottle name identifier
        let name: String
        /// Bottle version number
        let version: Int

        enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case compatibleApps = "compatible_apps"
            case cxSystem = "cx_system"
            case cxVersion = "cx_version"
            case cxVersions = "cx_versions"
            case description
            case isDefault = "is_default"
            case manifest
            case name
            case version
        }
    }

    /// Epic Games Launcher OAuth and API configuration.
    /// **File:** `version.json`
    struct EGLConfig: Codable {
        /// OAuth client ID for Epic Games API
        let clientID: String
        /// OAuth client secret for Epic Games API
        let clientSecret: String
        /// Data encryption keys
        let dataKeys: [String]
        /// Configuration label identifier
        let label: String
        /// Epic Games Launcher version
        let version: String

        enum CodingKeys: String, CodingKey {
            case clientID = "client_id"
            case clientSecret = "client_secret"
            case dataKeys = "data_keys"
            case label
            case version
        }
    }

    /// Game-specific override configurations.
    /// Contains per-game settings that override default behavior.
    /// **File:** `version.json`
    struct GameOverrides: Codable {
        /// Custom executable paths for games that don't follow standard layout
        let executableOverride: [String: ExecutableOverridePlatforms]
        /// Reorder optimization settings for specific games
        let reorderOptimization: [String: ReorderOptimizationValue]
        /// SDL configuration values for specific games
        let sdlConfig: [String: Int]

        enum CodingKeys: String, CodingKey {
            case executableOverride = "executable_override"
            case reorderOptimization = "reorder_optimization"
            case sdlConfig = "sdl_config"
        }
    }

    /// Platform-specific executable path overrides.
    ///
    /// **File:** `version.json`
    struct ExecutableOverridePlatforms: Codable {
        /// macOS executable path relative to game directory
        let darwin: String?
        /// Linux executable path relative to game directory
        let linux: String?
        /// Windows executable path relative to game directory
        let win32: String?

        enum CodingKeys: String, CodingKey {
            case darwin
            case linux
            case win32
        }
    }

    /// Reorder optimization value.
    /// Can be either an empty dictionary (no optimization) or an array of version strings.
    /// **File:** `version.json`
    enum ReorderOptimizationValue: Codable {
        /// No reorder optimization enabled
        case emptyDict
        /// Reorder optimization enabled for specific versions
        case stringArray([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let dict = try? container.decode([String: String].self), dict.isEmpty {
                self = .emptyDict
            } else if let array = try? container.decode([String].self) {
                self = .stringArray(array)
            } else {
                throw DecodingError.typeMismatch(
                    ReorderOptimizationValue.self,
                    DecodingError.Context(codingPath: decoder.codingPath,
                                          debugDescription: "Expected empty dict or string array")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .emptyDict:
                try container.encode([String: String]())
            case .stringArray(let array):
                try container.encode(array)
            }
        }
    }

    /// Game wiki URLs per platform.
    /// /// **File:** `version.json`
    struct GameWikiPlatforms: Codable {
        /// Wiki URL for macOS-specific information
        let darwin: String?
        /// Wiki URL for Linux-specific information
        let linux: String?
        /// Wiki URL for Windows-specific information
        let win32: String?

        enum CodingKeys: String, CodingKey {
            case darwin
            case linux
            case win32
        }
    }

    /// Legendary CLI configuration flags.
    /// **File:** `version.json`
    struct LegendaryConfig: Codable {
        /// Whether webview-based login is disabled
        let webviewKillswitch: Bool

        enum CodingKeys: String, CodingKey {
            case webviewKillswitch = "webview_killswitch"
        }
    }

    /// Legendary CLI release information.
    ///  **File:** `version.json`
    struct ReleaseInfo: Codable {
        /// Whether this update is critical and should be applied immediately
        let critical: Bool
        /// SHA256 hashes of platform-specific downloads
        let downloadHashes: DownloadHashes
        /// Download URLs for platform-specific binaries
        let downloads: Downloads
        /// GitHub release page URL
        let ghURL: String
        /// Release code name
        let name: String
        /// Release summary and changelog
        let summary: String
        /// Semantic version number
        let version: String

        enum CodingKeys: String, CodingKey {
            case critical
            case downloadHashes = "download_hashes"
            case downloads
            case ghURL = "gh_url"
            case name
            case summary
            case version
        }
    }

    /// Platform-specific download SHA256 hashes.
    /// **File:** `version.json`
    struct DownloadHashes: Codable {
        /// Linux binary SHA256 hash
        let linux: String
        /// macOS binary SHA256 hash
        let macos: String
        /// Windows binary SHA256 hash
        let windows: String

        enum CodingKeys: String, CodingKey {
            case linux
            case macos
            case windows
        }
    }

    /// Platform-specific download URLs.
    /// **File:** `version.json`
    struct Downloads: Codable {
        /// Linux binary download URL
        let linux: String
        /// macOS binary download URL
        let macos: String
        /// Windows binary download URL
        let windows: String

        enum CodingKeys: String, CodingKey {
            case linux
            case macos
            case windows
        }
    }

    typealias AssetInfos = [String: Asset]

    /// Sidecar configuration data for a game.
    /// Contains additional configuration that can be updated independently of the main manifest.
    /// **File:** `metadata/{app_name}.json`
    struct Sidecar: Codable {
        /// Sidecar configuration dictionary (can contain mixed types)
        let config: [String: CodableValue]
        /// Sidecar revision number
        let rev: Int

        enum CodingKeys: String, CodingKey {
            case config
            case rev
        }
    }

    /// A type-erased Codable value that can represent any JSON value
    enum CodableValue: Codable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case dictionary([String: CodableValue])
        case array([CodableValue])
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Int.self) {
                self = .int(value)
            } else if let value = try? container.decode(Double.self) {
                self = .double(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([String: CodableValue].self) {
                self = .dictionary(value)
            } else if let value = try? container.decode([CodableValue].self) {
                self = .array(value)
            } else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "Unable to decode CodableValue")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .string(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .double(let value):
                try container.encode(value)
            case .bool(let value):
                try container.encode(value)
            case .dictionary(let value):
                try container.encode(value)
            case .array(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }
    }

    // MARK: - metadata/*.json
    /// Root structure for game metadata FileManager.default.
    /// Contains comprehensive game information from the Epic Games Store catalog.
    /// **File:** `metadata/{app_name}.json`
    struct GameMetadata: Codable {
        /// Application identifier
        let appName: String
        /// Human-readable application title
        let appTitle: String
        /// Platform-specific asset information
        let assetInfos: AssetInfos
        /// Download base URLs for game files
        let baseURLs: [String]
        /// Detailed Epic Games Store metadata
        let storeMetadata: GameMetadataDetails
        /// Optional sidecar configuration data
        let sidecar: Sidecar?

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case appTitle = "app_title"
            case assetInfos = "asset_infos"
            case baseURLs = "base_urls"
            case storeMetadata = "metadata"
            case sidecar
        }
    }

    /// Detailed game metadata from Epic Games Store catalog.
    /// **File:** `metadata/{app_name}.json`
    struct GameMetadataDetails: Codable, Identifiable {
        /// Age rating information for different rating systems
        let ageGatings: [String: AgeGating]?
        /// OAuth application ID (if the game has online features)
        let applicationID: String?
        /// Epic Games Store category paths
        let categories: [Category]
        /// Item creation timestamp (ISO 8601)
        let creationDate: Date
        /// Custom game-specific attributes
        let customAttributes: [String: CustomAttribute]?
        /// Game description text
        let description: String
        /// Developer or publisher name
        let developer: String
        /// Developer organization identifier
        let developerID: String
        /// List of DLC and addon items
        let dlcItemList: [DLCItem]?
        /// Whether this game is no longer supported
        let endOfSupport: Bool
        /// Entitlement identifier
        let entitlementName: String
        /// Entitlement type (e.g., "EXECUTABLE", "AUDIENCE", "ENTITLEMENT")
        let entitlementType: String
        /// End User License Agreement identifiers
        let eulaIDs: [String]?
        /// Item catalog identifier
        let id: String
        /// Item type (e.g., "DURABLE", "CONSUMABLE")
        let itemType: String
        /// Key art and promotional images
        let keyImages: [KeyImage]
        /// Last modification timestamp (ISO 8601)
        let lastModifiedDate: Date
        /// Legal footer text (copyright, trademarks)
        let legalFooterText: String?
        /// Extended game description
        let longDescription: String?
        /// Main game item this DLC/addon belongs to (only present for DLC)
        let mainGameItem: MainGameItem?
        /// List of main game items (empty for main games, may contain parent for DLC)
        let mainGameItemList: [MainGameItem]?
        /// Epic Games Store namespace
        let namespace: String
        /// Platform-specific release information
        let releaseInfo: [GameReleaseInfo]
        /// Whether a secure Epic Games account is required
        let requiresSecureAccount: Bool?
        /// Item status in the catalog (e.g., "ACTIVE")
        let status: String
        /// Technical requirements and details
        let technicalDetails: String?
        /// Display title
        let title: String
        /// Whether this item is hidden from search
        let unsearchable: Bool

        enum CodingKeys: String, CodingKey {
            case ageGatings = "ageGatings"
            case applicationID = "applicationId"
            case categories
            case creationDate = "creationDate"
            case customAttributes = "customAttributes"
            case description
            case developer
            case developerID = "developerId"
            case dlcItemList = "dlcItemList"
            case endOfSupport = "endOfSupport"
            case entitlementName = "entitlementName"
            case entitlementType = "entitlementType"
            case eulaIDs = "eulaIds"
            case id
            case itemType = "itemType"
            case keyImages = "keyImages"
            case lastModifiedDate = "lastModifiedDate"
            case legalFooterText = "legalFooterText"
            case longDescription = "longDescription"
            case mainGameItem = "mainGameItem"
            case mainGameItemList = "mainGameItemList"
            case namespace
            case releaseInfo = "releaseInfo"
            case requiresSecureAccount = "requiresSecureAccount"
            case status
            case technicalDetails = "technicalDetails"
            case title
            case unsearchable
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            ageGatings = try container.decodeIfPresent([String: AgeGating].self, forKey: .ageGatings)
            applicationID = try container.decodeIfPresent(String.self, forKey: .applicationID)
            categories = try container.decode([Category].self, forKey: .categories)

            let creationDateString = try container.decode(String.self, forKey: .creationDate)
            guard let creationDateDate = dateFormatter.date(from: creationDateString) else {
                throw DecodingError.dataCorruptedError(forKey: .creationDate,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            creationDate = creationDateDate

            customAttributes = try container.decodeIfPresent([String: CustomAttribute].self, forKey: .customAttributes)
            description = try container.decode(String.self, forKey: .description)
            developer = try container.decode(String.self, forKey: .developer)
            developerID = try container.decode(String.self, forKey: .developerID)
            dlcItemList = try container.decodeIfPresent([DLCItem].self, forKey: .dlcItemList)
            endOfSupport = try container.decode(Bool.self, forKey: .endOfSupport)
            entitlementName = try container.decode(String.self, forKey: .entitlementName)
            entitlementType = try container.decode(String.self, forKey: .entitlementType)
            eulaIDs = try container.decodeIfPresent([String].self, forKey: .eulaIDs)
            id = try container.decode(String.self, forKey: .id)
            itemType = try container.decode(String.self, forKey: .itemType)
            keyImages = try container.decode([KeyImage].self, forKey: .keyImages)

            let lastModifiedDateString = try container.decode(String.self, forKey: .lastModifiedDate)
            guard let lastModifiedDateDate = dateFormatter.date(from: lastModifiedDateString) else {
                throw DecodingError.dataCorruptedError(forKey: .lastModifiedDate,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            lastModifiedDate = lastModifiedDateDate

            legalFooterText = try container.decodeIfPresent(String.self, forKey: .legalFooterText)
            longDescription = try container.decodeIfPresent(String.self, forKey: .longDescription)
            mainGameItem = try container.decodeIfPresent(MainGameItem.self, forKey: .mainGameItem)
            mainGameItemList = try container.decodeIfPresent([MainGameItem].self, forKey: .mainGameItemList)
            namespace = try container.decode(String.self, forKey: .namespace)
            releaseInfo = try container.decode([GameReleaseInfo].self, forKey: .releaseInfo)
            requiresSecureAccount = try container.decodeIfPresent(Bool.self, forKey: .requiresSecureAccount)
            status = try container.decode(String.self, forKey: .status)
            technicalDetails = try container.decodeIfPresent(String.self, forKey: .technicalDetails)
            title = try container.decode(String.self, forKey: .title)
            unsearchable = try container.decode(Bool.self, forKey: .unsearchable)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try container.encodeIfPresent(ageGatings, forKey: .ageGatings)
            try container.encodeIfPresent(applicationID, forKey: .applicationID)
            try container.encode(categories, forKey: .categories)
            try container.encode(dateFormatter.string(from: creationDate), forKey: .creationDate)
            try container.encodeIfPresent(customAttributes, forKey: .customAttributes)
            try container.encode(description, forKey: .description)
            try container.encode(developer, forKey: .developer)
            try container.encode(developerID, forKey: .developerID)
            try container.encodeIfPresent(dlcItemList, forKey: .dlcItemList)
            try container.encode(endOfSupport, forKey: .endOfSupport)
            try container.encode(entitlementName, forKey: .entitlementName)
            try container.encode(entitlementType, forKey: .entitlementType)
            try container.encode(eulaIDs, forKey: .eulaIDs)
            try container.encode(id, forKey: .id)
            try container.encode(itemType, forKey: .itemType)
            try container.encode(keyImages, forKey: .keyImages)
            try container.encode(dateFormatter.string(from: lastModifiedDate), forKey: .lastModifiedDate)
            try container.encodeIfPresent(legalFooterText, forKey: .legalFooterText)
            try container.encodeIfPresent(longDescription, forKey: .longDescription)
            try container.encodeIfPresent(mainGameItem, forKey: .mainGameItem)
            try container.encodeIfPresent(mainGameItemList, forKey: .mainGameItemList)
            try container.encode(namespace, forKey: .namespace)
            try container.encode(releaseInfo, forKey: .releaseInfo)
            try container.encodeIfPresent(requiresSecureAccount, forKey: .requiresSecureAccount)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(technicalDetails, forKey: .technicalDetails)
            try container.encode(title, forKey: .title)
            try container.encode(unsearchable, forKey: .unsearchable)
        }
    }

    /// Age rating information for a specific rating system.
    /// **File:** `metadata/{app_name}.json`
    struct AgeGating: Codable {
        /// Minimum age requirement for this rating
        let ageControl: Int
        /// Content descriptors (e.g., "Violence", "Language")
        let descriptor: String?
        /// Numeric descriptor identifiers
        let descriptorIDs: [Int]?
        /// Interactive elements (e.g., "Users Interact", "In-Game Purchases")
        let element: String?
        /// Numeric element identifiers
        let elementIDs: [Int]?
        /// Rating classification string
        let gameRating: String
        /// Whether this is an IARC (International Age Rating Coalition) rating
        let isIARC: Bool
        /// Whether this is a traditional/legacy rating
        let isTrad: Bool
        /// Square rating badge image URL
        let ratingImage: String?
        /// Rating system identifier (e.g., "ESRB", "PEGI", "USK")
        let ratingSystem: String
        /// Rectangular rating badge image URL
        let rectangularRatingImage: String?
        /// Display title for this rating
        let title: String

        enum CodingKeys: String, CodingKey {
            case ageControl = "ageControl"
            case descriptor
            case descriptorIDs = "descriptorIds"
            case element
            case elementIDs = "elementIds"
            case gameRating = "gameRating"
            case isIARC = "isIARC"
            case isTrad = "isTrad"
            case ratingImage = "ratingImage"
            case ratingSystem = "ratingSystem"
            case rectangularRatingImage = "rectangularRatingImage"
            case title
        }
    }

    /// Epic Games Store category.
    /// **File:** `metadata/{app_name}.json`
    struct Category: Codable {
        /// Category path (e.g., "games", "applications", "addons")
        let path: String

        enum CodingKeys: String, CodingKey {
            case path
        }
    }

    /// Custom attribute key-value pair.
    /// /// **File:** `metadata/{app_name}.json`
    struct CustomAttribute: Codable {
        /// Attribute data type (usually "STRING")
        let type: String
        /// Attribute value
        let value: String

        enum CodingKeys: String, CodingKey {
            case type
            case value
        }
    }

    /// DLC, addon, or related content item.
    /// **File:** `metadata/{app_name}.json`
    struct DLCItem: Codable, Identifiable {
        /// Age ratings for this DLC
        let ageGatings: [String: AgeGating]?
        /// OAuth application ID
        let applicationID: String?
        /// Store categories
        let categories: [Category]
        /// Creation timestamp
        let creationDate: Date
        /// Custom attributes
        let customAttributes: [String: CustomAttribute]?
        /// DLC description
        let description: String
        /// Developer name
        let developer: String
        /// Developer organization ID
        let developerID: String
        /// End of support flag
        let endOfSupport: Bool
        /// Entitlement identifier
        let entitlementName: String
        /// Entitlement type
        let entitlementType: String
        /// EULA identifiers
        let eulaIDs: [String]?
        /// Catalog item ID
        let id: String
        /// Item type
        let itemType: String
        /// Key art images
        let keyImages: [KeyImage]?
        /// Last modification timestamp
        let lastModifiedDate: Date
        /// Parent game reference
        let mainGameItem: MainGameItem?
        /// Parent game references
        let mainGameItemList: [MainGameItem]?
        /// Store namespace
        let namespace: String
        /// Platform release information
        let releaseInfo: [GameReleaseInfo]?
        /// Secure account requirement
        let requiresSecureAccount: Bool?
        /// Catalog status
        let status: String
        /// Display title
        let title: String
        /// Search visibility
        let unsearchable: Bool
        /// Use count for consumables
        let useCount: Int?

        enum CodingKeys: String, CodingKey {
            case ageGatings = "ageGatings"
            case applicationID = "applicationId"
            case categories
            case creationDate = "creationDate"
            case customAttributes = "customAttributes"
            case description
            case developer
            case developerID = "developerId"
            case endOfSupport = "endOfSupport"
            case entitlementName = "entitlementName"
            case entitlementType = "entitlementType"
            case eulaIDs = "eulaIds"
            case id
            case itemType = "itemType"
            case keyImages = "keyImages"
            case lastModifiedDate = "lastModifiedDate"
            case mainGameItem = "mainGameItem"
            case mainGameItemList = "mainGameItemList"
            case namespace
            case releaseInfo = "releaseInfo"
            case requiresSecureAccount = "requiresSecureAccount"
            case status
            case title
            case unsearchable
            case useCount = "useCount"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            ageGatings = try container.decodeIfPresent([String: AgeGating].self, forKey: .ageGatings)
            applicationID = try container.decodeIfPresent(String.self, forKey: .applicationID)
            categories = try container.decode([Category].self, forKey: .categories)

            let creationDateString = try container.decode(String.self, forKey: .creationDate)
            guard let creationDateDate = dateFormatter.date(from: creationDateString) else {
                throw DecodingError.dataCorruptedError(forKey: .creationDate,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            creationDate = creationDateDate

            customAttributes = try container.decodeIfPresent([String: CustomAttribute].self, forKey: .customAttributes)
            description = try container.decode(String.self, forKey: .description)
            developer = try container.decode(String.self, forKey: .developer)
            developerID = try container.decode(String.self, forKey: .developerID)
            endOfSupport = try container.decode(Bool.self, forKey: .endOfSupport)
            entitlementName = try container.decode(String.self, forKey: .entitlementName)
            entitlementType = try container.decode(String.self, forKey: .entitlementType)
            eulaIDs = try container.decodeIfPresent([String].self, forKey: .eulaIDs)
            id = try container.decode(String.self, forKey: .id)
            itemType = try container.decode(String.self, forKey: .itemType)
            keyImages = try container.decodeIfPresent([KeyImage].self, forKey: .keyImages)

            let lastModifiedDateString = try container.decode(String.self, forKey: .lastModifiedDate)
            guard let lastModifiedDateDate = dateFormatter.date(from: lastModifiedDateString) else {
                throw DecodingError.dataCorruptedError(forKey: .lastModifiedDate,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            lastModifiedDate = lastModifiedDateDate

            mainGameItem = try container.decodeIfPresent(MainGameItem.self, forKey: .mainGameItem)
            mainGameItemList = try container.decodeIfPresent([MainGameItem].self, forKey: .mainGameItemList)
            namespace = try container.decode(String.self, forKey: .namespace)
            releaseInfo = try container.decodeIfPresent([GameReleaseInfo].self, forKey: .releaseInfo)
            requiresSecureAccount = try container.decodeIfPresent(Bool.self, forKey: .requiresSecureAccount)
            status = try container.decode(String.self, forKey: .status)
            title = try container.decode(String.self, forKey: .title)
            unsearchable = try container.decode(Bool.self, forKey: .unsearchable)
            useCount = try container.decodeIfPresent(Int.self, forKey: .useCount)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try container.encodeIfPresent(ageGatings, forKey: .ageGatings)
            try container.encodeIfPresent(applicationID, forKey: .applicationID)
            try container.encode(categories, forKey: .categories)
            try container.encode(dateFormatter.string(from: creationDate), forKey: .creationDate)
            try container.encodeIfPresent(customAttributes, forKey: .customAttributes)
            try container.encode(description, forKey: .description)
            try container.encode(developer, forKey: .developer)
            try container.encode(developerID, forKey: .developerID)
            try container.encode(endOfSupport, forKey: .endOfSupport)
            try container.encode(entitlementName, forKey: .entitlementName)
            try container.encode(entitlementType, forKey: .entitlementType)
            try container.encodeIfPresent(eulaIDs, forKey: .eulaIDs)
            try container.encode(id, forKey: .id)
            try container.encode(itemType, forKey: .itemType)
            try container.encodeIfPresent(keyImages, forKey: .keyImages)
            try container.encode(dateFormatter.string(from: lastModifiedDate), forKey: .lastModifiedDate)
            try container.encodeIfPresent(mainGameItem, forKey: .mainGameItem)
            try container.encodeIfPresent(mainGameItemList, forKey: .mainGameItemList)
            try container.encode(namespace, forKey: .namespace)
            try container.encodeIfPresent(releaseInfo, forKey: .releaseInfo)
            try container.encodeIfPresent(requiresSecureAccount, forKey: .requiresSecureAccount)
            try container.encode(status, forKey: .status)
            try container.encode(title, forKey: .title)
            try container.encode(unsearchable, forKey: .unsearchable)
            try container.encodeIfPresent(useCount, forKey: .useCount)
        }
    }

    /// Key art or promotional image metadata.
    /// **File:** `metadata/{app_name}.json`
    struct KeyImage: Codable {
        /// Image height in pixels
        let height: Int
        /// MD5 hash of the image file
        let md5: String
        /// File size in bytes
        let size: Int
        /// Image type identifier (e.g., "DieselGameBox", "DieselGameBoxTall", "Featured")
        let type: String
        /// Upload timestamp (ISO 8601)
        let uploadedDate: Date
        /// CDN URL for the image
        let url: String
        /// Image width in pixels
        let width: Int

        enum CodingKeys: String, CodingKey {
            case height
            case md5
            case size
            case type
            case uploadedDate
            case url
            case width
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            height = try container.decode(Int.self, forKey: .height)
            md5 = try container.decode(String.self, forKey: .md5)
            size = try container.decode(Int.self, forKey: .size)
            type = try container.decode(String.self, forKey: .type)

            let uploadedDateString = try container.decode(String.self, forKey: .uploadedDate)
            guard let uploadedDateDate = dateFormatter.date(from: uploadedDateString) else {
                throw DecodingError.dataCorruptedError(forKey: .uploadedDate,
                                                       in: container,
                                                       debugDescription: "Invalid ISO8601 date format")
            }
            uploadedDate = uploadedDateDate

            url = try container.decode(String.self, forKey: .url)
            width = try container.decode(Int.self, forKey: .width)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try container.encode(height, forKey: .height)
            try container.encode(md5, forKey: .md5)
            try container.encode(size, forKey: .size)
            try container.encode(type, forKey: .type)
            try container.encode(dateFormatter.string(from: uploadedDate), forKey: .uploadedDate)
            try container.encode(url, forKey: .url)
            try container.encode(width, forKey: .width)
        }
    }

    /// Reference to a main game item.
    /// **File:** `metadata/{app_name}.json`
    struct MainGameItem: Codable, Identifiable {
        /// Catalog item identifier
        let id: String
        /// Store namespace
        let namespace: String
        /// Whether the item is hidden from search
        let unsearchable: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case namespace
            case unsearchable
        }
    }

    /// Platform-specific release information.
    /// **File:** `metadata/{app_name}.json`
    struct GameReleaseInfo: Codable, Identifiable {
        /// Application identifier for this release
        let appID: String
        /// List of compatible app IDs
        let compatibleApps: [String]?
        /// Release date (ISO 8601)
        let dateAdded: Date?
        /// Release identifier
        let id: String
        /// Supported platforms (e.g., ["Windows", "Mac"])
        let _platform: [String] // swiftlint:disable:this identifier_name
        var platform: [Game.Platform] { _platform.compactMap({ matchPlatformString(for: $0) }) }

        enum CodingKeys: String, CodingKey {
            case appID = "appId"
            case compatibleApps = "compatibleApps"
            case dateAdded = "dateAdded"
            case id
            case _platform = "platform" // swiftlint:disable:this identifier_name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            appID = try container.decode(String.self, forKey: .appID)
            compatibleApps = try container.decodeIfPresent([String].self, forKey: .compatibleApps)

            if let dateAddedString = try container.decodeIfPresent(String.self, forKey: .dateAdded) {
                guard let dateAddedDate = dateFormatter.date(from: dateAddedString) else {
                    throw DecodingError.dataCorruptedError(forKey: .dateAdded,
                                                           in: container,
                                                           debugDescription: "Invalid ISO8601 date format")
                }

                dateAdded = dateAddedDate
            } else {
                dateAdded = nil
            }

            id = try container.decode(String.self, forKey: .id)
            _platform = try container.decode([String].self, forKey: ._platform)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let dateFormatter: ISO8601DateFormatter = .init()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try container.encode(appID, forKey: .appID)
            try container.encodeIfPresent(compatibleApps, forKey: .compatibleApps)
            if let dateAdded {
                try container.encodeIfPresent(dateFormatter.string(from: dateAdded), forKey: .dateAdded)
            }
            try container.encode(id, forKey: .id)
            try container.encode(_platform, forKey: ._platform)
        }
    }
}
// swiftlint:enable nesting

extension Legendary.Asset: Identifiable {
    var id: String { assetID }
}

extension Legendary.InstalledGame: Identifiable {
    var id: String { appName }
}

extension Legendary {
    /// Enumeration to specify image types.
    enum ImageType {
        case normal
        case tall
    }

    struct UnableToRetrieveError: LocalizedError {
        var errorDescription: String? = String(localized: "Mythic is unable to retrive the requested metadata for this game.")
    }

    /// Error when legendary is signed out on a command that enforces signin.
    struct NotSignedInError: LocalizedError {
        var errorDescription: String? = String(localized: "You aren't signed in to Epic Games.")
    }

    struct SignInError: LocalizedError {
        var errorDescription: String? = String(localized: "Unable to sign in to Epic Games.")
    }

    struct UnsupportedInstallationPlatformError: LocalizedError {
        var errorDescription: String? = String(localized: "The selected platform is unsupported for installation.")
    }

    struct GenericError: LocalizedError {
        init(reason: String = .init()) {
            self.reason = reason
        }

        var errorDescription: String? { String(localized: "An error occurred while interfacing with Epic Games.") + "\n" + reason }
        var reason: String
    }
}
