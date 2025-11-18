//
//  LegendaryInterface+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation

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
        let assetId: String
        /// Build version string
        let buildVersion: String
        /// Catalog item identifier in the Epic Games Store
        let catalogItemId: String
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
            case assetId = "asset_id"
            case buildVersion = "build_version"
            case catalogItemId = "catalog_item_id"
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
        let installationPoolId: String?
        /// Type of update (e.g., "MINOR", "PATCH", "MAJOR")
        let updateType: String?

        enum CodingKeys: String, CodingKey {
            case installationPoolId = "installationPoolId"
            case updateType = "update_type"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            installationPoolId = try container.decodeIfPresent(String.self, forKey: .installationPoolId)
            updateType = try container.decodeIfPresent(String.self, forKey: .updateType)
        }
    }

    // MARK: - installed.json
    /// A dictionary mapping app names to their installation details.
    /// Each key is an app_name and the value contains complete installation information.
    /// **File:** `installed.json`
    typealias Installed = [String: InstalledGame]

    /// Represents an installed game with all its configuration.
    /// Contains paths, version info, and installation metadata.
    /// **File:** `installed.json`
    struct InstalledGame: Codable {
        /// Application identifier
        let appName: String
        /// Download base URLs for game files
        let baseUrls: [String]
        /// Whether the game can run without internet connection
        let canRunOffline: Bool
        /// Epic Games Launcher GUID
        let eglGuid: String
        /// Executable path relative to install path
        let executable: String
        /// Full installation directory path
        let installPath: String
        /// Installation size in bytes
        let installSize: Int
        /// Installation tags (usually empty)
        let installTags: [String]
        /// Whether this is DLC content
        let isDlc: Bool
        /// Additional command-line launch parameters
        let launchParameters: String
        /// Path to the manifest file
        let manifestPath: String?
        /// Whether the installation needs verification
        let needsVerification: Bool
        /// Platform identifier (e.g., "Windows", "Mac")
        let platform: String
        /// Prerequisite installation information (path or configuration string)
        let prereqInfo: String?
        /// Whether it requires OT (Online Token)
        let requiresOt: Bool
        /// Path to save files
        let savePath: String?
        /// Human-readable game title
        let title: String
        /// Path to uninstaller executable
        let uninstaller: String?
        /// Installed version string
        let version: String

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case baseUrls = "base_urls"
            case canRunOffline = "can_run_offline"
            case eglGuid = "egl_guid"
            case executable
            case installPath = "install_path"
            case installSize = "install_size"
            case installTags = "install_tags"
            case isDlc = "is_dlc"
            case launchParameters = "launch_parameters"
            case manifestPath = "manifest_path"
            case needsVerification = "needs_verification"
            case platform
            case prereqInfo = "prereq_info"
            case requiresOt = "requires_ot"
            case savePath = "save_path"
            case title
            case uninstaller
            case version
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
        let accountId: String
        /// Authentication context class reference
        let acr: String
        /// Application identifier
        let app: String
        /// Authentication timestamp (ISO 8601 format)
        let authTime: String
        /// OAuth client identifier
        let clientId: String
        /// Client service name (e.g., "launcher")
        let clientService: String
        /// Unique device identifier
        let deviceId: String
        /// User's display name
        let displayName: String
        /// Access token expiration timestamp (ISO 8601 format)
        let expiresAt: String
        /// Access token expiration duration in seconds
        let expiresIn: Int
        /// In-app user identifier
        let inAppId: String
        /// Whether this is an internal Epic Games client
        let internalClient: Bool
        /// Refresh token expiration duration in seconds
        let refreshExpires: Int
        /// Refresh token expiration timestamp (ISO 8601 format)
        let refreshExpiresAt: String
        /// Refresh token for obtaining new access tokens
        let refreshToken: String
        /// OAuth scopes granted to this token
        let scope: [String]
        /// Token type (typically "bearer")
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountId = "account_id"
            case acr
            case app
            case authTime = "auth_time"
            case clientId = "client_id"
            case clientService = "client_service"
            case deviceId = "device_id"
            case displayName
            case expiresAt = "expires_at"
            case expiresIn = "expires_in"
            case inAppId = "in_app_id"
            case internalClient = "internal_client"
            case refreshExpires = "refresh_expires"
            case refreshExpiresAt = "refresh_expires_at"
            case refreshToken = "refresh_token"
            case scope
            case tokenType = "token_type"
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
        let baseUrl: String?
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
            case baseUrl = "base_url"
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
        let clientId: String
        /// OAuth client secret for Epic Games API
        let clientSecret: String
        /// Data encryption keys
        let dataKeys: [String]
        /// Configuration label identifier
        let label: String
        /// Epic Games Launcher version
        let version: String

        enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
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
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected empty dict or string array")
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
        let ghUrl: String
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
            case ghUrl = "gh_url"
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
    }

    // MARK: - metadata/*.json
    /// Root structure for game metadata files.
    /// Contains comprehensive game information from the Epic Games Store catalog.
    /// **File:** `metadata/{app_name}.json`
    struct GameMetadata: Codable {
        /// Application identifier
        let appName: String
        /// Human-readable application title
        let appTitle: String
        /// Platform-specific asset information
        let assetInfos: [String: Asset]
        /// Download base URLs for game files
        let baseUrls: [String]
        /// Detailed Epic Games Store metadata
        let metadata: GameMetadataDetails

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case appTitle = "app_title"
            case assetInfos = "asset_infos"
            case baseUrls = "base_urls"
            case metadata
        }
    }

    /// Detailed game metadata from Epic Games Store catalog.
    /// **File:** `metadata/{app_name}.json`
    struct GameMetadataDetails: Codable {
        /// Age rating information for different rating systems
        let ageGatings: [String: AgeGating]?
        /// OAuth application ID (if the game has online features)
        let applicationId: String?
        /// Epic Games Store category paths
        let categories: [Category]
        /// Item creation timestamp (ISO 8601)
        let creationDate: String
        /// Custom game-specific attributes
        let customAttributes: [String: CustomAttribute]
        /// Game description text
        let description: String
        /// Developer or publisher name
        let developer: String
        /// Developer organization identifier
        let developerId: String
        /// List of DLC and addon items
        let dlcItemList: [DLCItem]?
        /// Whether this game is no longer supported
        let endOfSupport: Bool
        /// Entitlement identifier
        let entitlementName: String
        /// Entitlement type (e.g., "EXECUTABLE", "AUDIENCE", "ENTITLEMENT")
        let entitlementType: String
        /// End User License Agreement identifiers
        let eulaIds: [String]
        /// Item catalog identifier
        let id: String
        /// Item type (e.g., "DURABLE", "CONSUMABLE")
        let itemType: String
        /// Key art and promotional images
        let keyImages: [KeyImage]
        /// Last modification timestamp (ISO 8601)
        let lastModifiedDate: String
        /// Legal footer text (copyright, trademarks)
        let legalFooterText: String?
        /// Extended game description
        let longDescription: String?
        /// Main game items this content belongs to
        let mainGameItemList: [MainGameItem]?
        /// Epic Games Store namespace
        let namespace: String
        /// Platform-specific release information
        let releaseInfo: [ReleaseInfo2]
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
    }

    /// Age rating information for a specific rating system.
    /// **File:** `metadata/{app_name}.json`
    struct AgeGating: Codable {
        /// Minimum age requirement for this rating
        let ageControl: Int
        /// Content descriptors (e.g., "Violence", "Language")
        let descriptor: String?
        /// Numeric descriptor identifiers
        let descriptorIds: [Int]?
        /// Interactive elements (e.g., "Users Interact", "In-Game Purchases")
        let element: String?
        /// Numeric element identifiers
        let elementIds: [Int]?
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
    }

    /// Epic Games Store category.
    /// **File:** `metadata/{app_name}.json`
    struct Category: Codable {
        /// Category path (e.g., "games", "applications", "addons")
        let path: String
    }

    /// Custom attribute key-value pair.
    /// /// **File:** `metadata/{app_name}.json`
    struct CustomAttribute: Codable {
        /// Attribute data type (usually "STRING")
        let type: String
        /// Attribute value
        let value: String
    }

    /// DLC, addon, or related content item.
    /// **File:** `metadata/{app_name}.json`
    struct DLCItem: Codable {
        /// Age ratings for this DLC
        let ageGatings: [String: AgeGating]?
        /// OAuth application ID
        let applicationId: String?
        /// Store categories
        let categories: [Category]
        /// Creation timestamp
        let creationDate: String
        /// Custom attributes
        let customAttributes: [String: CustomAttribute]?
        /// DLC description
        let description: String
        /// Developer name
        let developer: String
        /// Developer organization ID
        let developerId: String
        /// End of support flag
        let endOfSupport: Bool
        /// Entitlement identifier
        let entitlementName: String
        /// Entitlement type
        let entitlementType: String
        /// EULA identifiers
        let eulaIds: [String]
        /// Catalog item ID
        let id: String
        /// Item type
        let itemType: String
        /// Key art images
        let keyImages: [KeyImage]?
        /// Last modification timestamp
        let lastModifiedDate: String
        /// Parent game reference
        let mainGameItem: MainGameItem?
        /// Parent game references
        let mainGameItemList: [MainGameItem]?
        /// Store namespace
        let namespace: String
        /// Platform release information
        let releaseInfo: [ReleaseInfo2]?
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
        let uploadedDate: String
        /// CDN URL for the image
        let url: String
        /// Image width in pixels
        let width: Int
    }

    /// Reference to a main game item.
    /// **File:** `metadata/{app_name}.json`
    struct MainGameItem: Codable {
        /// Catalog item identifier
        let id: String
        /// Store namespace
        let namespace: String
        /// Whether the item is hidden from search
        let unsearchable: Bool
    }

    /// Platform-specific release information.
    /// **File:** `metadata/{app_name}.json`
    struct ReleaseInfo2: Codable {
        /// Application identifier for this release
        let appId: String
        /// List of compatible app IDs
        let compatibleApps: [String]?
        /// Release date (ISO 8601)
        let dateAdded: String
        /// Release identifier
        let id: String
        /// Supported platforms (e.g., ["Windows", "Mac"])
        let platform: [String]
    }
}

extension Legendary {
    /// Enumeration to specify image types.
    enum ImageType {
        case normal
        case tall
    }

    enum RetrievalType {
        case platform
        case launchArguments
    }

    struct UnableToRetrieveError: LocalizedError {
        var errorDescription: String? = String(localized: "Mythic is unable to retrive the requested metadata for this game.")
    }

    struct IsNotLegendaryError: LocalizedError {
        var errorDescription: String? = String(localized: "This is not an Epic Games game.")
    }

    /// Error when legendary is signed out on a command that enforces signin.
    struct NotSignedInError: LocalizedError {
        var errorDescription: String? = String(localized: "You aren't signed in to Epic Games.")
    }

    struct SignInError: LocalizedError {
        var errorDescription: String? = "Unable to sign in to Epic Games."
    }

    struct GenericError: LocalizedError {
        init(reason: String = .init()) {
            self.reason = reason
        }

        var errorDescription: String? { String(localized: "An error occurred while interfacing with Epic Games.") + "\n" + reason }
        var reason: String
    }
}
