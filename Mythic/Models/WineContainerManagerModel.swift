//
//  WineContainerManagerModel.swift
//  Mythic
//

import Foundation

public final class WineContainerManagerModel: Sendable {
    public static let logger = AppLoggerModel(category: WineContainerManagerModel.self)

    /// Default base path for wine containers.
    public static let wineContainersBasePath = DirectoriesUtility.applicationSupportDirectory?
        .appendingPathComponent("WineContainers")

    /// The shared instance.
    public static let shared = WineContainerManagerModel()

    private final class Box<T>: @unchecked Sendable {
        public var value: T

        init(_ value: T) {
            self.value = value
        }
    }

    /// A dictionary of wine containers.
    private let wineContainers: Box<[UUID: WineContainerModel]> = .init([:])

    /// Initialize a new wine container manager.
    private init() {
        DispatchQueue.main.async {
            // Load the containers.
            self.loadContainers()
        }
    }

    /// Load the containers.
    @MainActor private func loadContainers() {
        // Load the containers.
        let store = WineContainersV1PersistentStateModel.shared.store
        for container in store.containers {
            let containerModel = WineContainerModel(
                containerID: container.key,
                containerInfo: container.value
            )
            wineContainers.value[container.key] = containerModel
        }
    }

    /// Get a wine container.
    /// - Parameter containerID: The container ID.
    /// - Returns: The wine container.
    public func getWineContainer(containerID: UUID) -> WineContainerModel? {
        wineContainers.value[containerID]
    }

    /// Create a new default container info.
    /// - Returns: The new default container info.
    private func createDefaultContainerInfo(
        uuid: UUID,
        name: String,
        path: URL
    ) -> WineContainersV1PersistentStateModel.WineContainer {
        .init(
            containerID: uuid,
            name: name,
            path: path,
            windowsVersion: .windows11,
            windowsBuild: 22000,
            retinaMode: false,
            dpiScaling: 96,
            syncType: .machSync,
            exposeAVX: false, direct3DTranslationLayer: .direct3DMetal,
            metalHUDEnabled: false,
            metalTracingEnabled: false,
            direct3DMetalDirectXRaytracingEnabled: false,
            dxvkAsyncEnabled: false,
            dxvkHUD: .none,
            discordRPCPassthrough: true
        )
    }

    /// Get the default wine container.
    /// - Returns: The default wine container.
    @MainActor public func getDefaultWineContainer() -> WineContainerModel {
        var store = WineContainersV1PersistentStateModel.shared.store
        let defaultContainerID = store.defaultContainerID
        if let container = wineContainers.value[defaultContainerID] {
            return container
        }

        let containerInfo = createDefaultContainerInfo(
            uuid: defaultContainerID,
            name: "Default",
            path: Self.wineContainersBasePath?.appendingPathComponent(
                defaultContainerID.uuidString) ?? .init(fileURLWithPath: "")
        )

        // Save the container.
        store.containers[defaultContainerID] = containerInfo

        // Create a new container.
        let container = WineContainerModel(
            containerID: defaultContainerID,
            containerInfo: containerInfo
        )

        return container
    }
}
