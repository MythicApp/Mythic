//
//  WineContainerModel.swift
//  Mythic
//

import Foundation

public final class WineContainerModel: Sendable {
    public static let logger = AppLoggerModel(category: WineContainerModel.self)

    /// The UUID of the container.
    public let containerID: UUID

    private final class Box<T>: @unchecked Sendable {
        public var value: T
        
        init(_ value: T) {
            self.value = value
        }
    }
    
    /// Container info.
    private let internalContainerInfo: Box<WineContainersV1PersistentStateModel.WineContainer>

    /// Initialize a new wine container.
    /// Please don't use this initializer directly, get one from `WineContainerManagerModel`.
    /// - Parameters:
    ///   - containerID: The container ID.
    ///   - winePackage: The wine package.
    ///   - containerInfo: The container info.
    /// - Returns: A new wine container.
    init(
        containerID: UUID,
        containerInfo: WineContainersV1PersistentStateModel.WineContainer
    ) {
        self.containerID = containerID
        self.internalContainerInfo = .init(containerInfo)
    }

    public enum WineContainerInitializationError: Error {
        case directoryCreationFailed(Error)
        case winebootFailed(Error)
        case winebootBadExitCode
    }

    /// Initialize the wine prefix.
    /// - Parameter winePackage: The wine package.
    /// - Returns: If the operation was successful.
    public func initializeWinePrefix(
        winePackage: EngineInstanceModel.WinePackage
    ) async -> Result<Void, WineContainerInitializationError> {
        // Create the directory.
        do {
            try FileManager.default.createDirectory(
                at: internalContainerInfo.value.path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            Self.logger.error(
                "Failed to create directory (\(containerID)): \(error.localizedDescription)")
            return .failure(.directoryCreationFailed(error))
        }

        let result = await WineCommandModel.createWinePrefix(
            package: winePackage,
            prefixURL: internalContainerInfo.value.path
        )

        switch result {
        case .success(true):
            return .success(())
        case .success(false):
            return .failure(.winebootBadExitCode)
        case .failure(let error):
            return .failure(.winebootFailed(error))
        }
    }

}
