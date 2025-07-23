//
//  WineContainersV1PersistentStateModel.swift
//  Mythic
//

import Foundation
import SemanticVersion

public struct WineContainersV1PersistentStateModel: StorablePersistentStateModel.State {
    /// Shared instance.
    @MainActor public static let shared: StorablePersistentStateModel.Store<Self> = .init()

    public typealias RootType = WineContainers
    public static let persistentStateStoreName = "WineContainersV1"

    public static func defaultValue() -> WineContainers {
        .init()
    }

    /// Sync type.
    public enum SyncType: String, Codable, Hashable {
        case machSync
        case enhancedSync
        case none
    }

    /// Windows versions.
    public enum WindowsVersion: String, Codable, Hashable {
        case windows11
        case windows10
        case windows8Point1
        case windows8
        case windows7
        case windowsVista
        case windowsXP64Bit
    }

    /// DXVK HUD options.
    public enum DXVKHUDOptions: String, Codable, Hashable {
        case full
        case minimal
        case fpsOnly
        case none
    }
    
    /// Direct3D Layer option
    public enum Direct3DLayer: String, Codable, Hashable {
        case directXVulkun
        case direct3DMetal
    }

    /// A wine container along with it's settings
    public struct WineContainer: Codable, Hashable, Equatable {
        /// The container ID.
        public var containerID: UUID
        /// The name.
        public var name: String
        /// The path.
        public var path: URL

        /// Windows version.
        public var windowsVersion: WindowsVersion
        /// Windows build.
        public var windowsBuild: Int

        /// Retina mode.
        public var retinaMode: Bool
        /// DPI scaling.
        public var dpiScaling: Int

        /// The sync type.
        public var syncType: SyncType
        /// Expose AVX (Rosetta).
        public var exposeAVX: Bool
        
        /// Direct3D Translation Layer.
        public var direct3DTranslationLayer: Direct3DLayer

        /// Metal HUD.
        public var metalHUDEnabled: Bool
        /// Metal tracing.
        public var metalTracingEnabled: Bool
        
        /// Direct3D Metal DirectX raytracing.
        public var direct3DMetalDirectXRaytracingEnabled: Bool

        /// DXVK async.
        public var dxvkAsyncEnabled: Bool
        /// DXVK HUD.
        public var dxvkHUD: DXVKHUDOptions

        /// Discord Rich Presence passthrough.
        public var discordRPCPassthrough: Bool
    }

    /// The wine containers.
    public struct WineContainers: Codable, Hashable, Equatable {
        /// Default container ID.
        public var defaultContainerID: UUID = .init()

        /// Containers.
        public var containers: [UUID: WineContainer] = [:]
    }
}
