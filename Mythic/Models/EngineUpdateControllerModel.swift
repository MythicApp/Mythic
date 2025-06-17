//
//  EngineUpdateControllerModel.swift
//  Mythic
//

import Foundation
import Combine

public final class EngineUpdateControllerModel: ObservableObject {
    /// The shared instance.
    public static let shared = EngineUpdateControllerModel()

    private let logger = AppLoggerModel(category: EngineUpdateControllerModel.self)

    /// State for a download.
    public enum ArtifactDownloadState: Hashable, Equatable, Sendable {
        case initializing
        case downloading(startDate: Date, total: UInt64?, downloaded: UInt64)
        case verifying

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .initializing: hasher.combine(0)
            case .downloading(let startDate, let total, let downloaded):
                hasher.combine(1)
                hasher.combine(startDate)
                hasher.combine(total)
                hasher.combine(downloaded)
            case .verifying: hasher.combine(2)
            }
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
    }

    /// A user choice
    public enum UserChoice: Hashable, Equatable, Sendable {
        case update
        case dismiss
    }

    /// The updater's state.
    public enum UpdaterState: Hashable, Equatable, Sendable {
        case idle
        case checkingForUpdates
        case noUpdateAvailable(
            dismiss: @Sendable () -> Void
        )
        case downloadingReleaseInfo(ArtifactDownloadState)
        case updateAvailable(
            update: @Sendable (UserChoice) -> Void,
            version: EngineVersionsDownloadModel.Version,
            releaseInfo: EngineVersionsDownloadModel.ReleaseInfo
        )
        case downloadingUpdate(ArtifactDownloadState)
        case verifyingUpdate
        case readyToInstall(
            install: @Sendable (UserChoice) -> Void
        )
        case installing
        case success(
            dismiss: @Sendable () -> Void
        )
        case failure(dismiss: @Sendable () -> Void, error: Error)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .idle: hasher.combine(0)
            case .checkingForUpdates: hasher.combine(1)
            case .noUpdateAvailable: hasher.combine(2)
            case .downloadingReleaseInfo(let state):
                hasher.combine(3)
                hasher.combine(state)
            case .updateAvailable(_, let version, let releaseInfo):
                hasher.combine(4)
                hasher.combine(version)
                hasher.combine(releaseInfo)
            case .downloadingUpdate(let state):
                hasher.combine(5)
                hasher.combine(state)
            case .verifyingUpdate: hasher.combine(6)
            case .readyToInstall: hasher.combine(7)
            case .installing: hasher.combine(8)
            case .success: hasher.combine(9)
            case .failure(_, let error):
                hasher.combine(10)
                hasher.combine(error.localizedDescription)
            }
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
    }

    /// Engine update internal error.
    public enum EngineUpdateError: LocalizedError {
        case unexpectedState
        case artifactReferenceUnresolved
        case hashVerificationFailed(UUID, String)
        case signatureVerificationFailed(UUID, String, String)
        case urlCreationError
        case pathCreationError(Error)
        case filesystemError(Error)
    }

    // Current state.
    @Published public private(set) var userInitiatedCheck: Bool = false
    @Published public private(set) var state: UpdaterState = .idle

    // Internal state.
    private var versionsFile: EngineVersionsDownloadModel.VersionsFile?
    private var latestVersion: EngineVersionsDownloadModel.Version?
    private var releaseInfo: EngineVersionsDownloadModel.ReleaseInfo?
    private var build: EngineVersionsDownloadModel.Build?
    private var downloadedTarball: URL?
    private var downloadedLatestVersion: EngineVersionsDownloadModel.Version?
    private var downloadedReleaseInfo: EngineVersionsDownloadModel.ReleaseInfo?
    private var downloadedBuild: EngineVersionsDownloadModel.Build?

    private var updateInternalStateCancellables: Set<AnyCancellable> = []
    private var updateSettingsCancellables: Set<AnyCancellable> = []
    private var backgroundTask: AnyCancellable?

    private init() {
        DispatchQueue.main.async {
            self.manageBackgroundTask(AppSettingsV1PersistentStateModel.shared.store.engineUpdateAction != .off &&
                !AppSettingsV1PersistentStateModel.shared.store.inOnboarding)
            AppSettingsV1PersistentStateModel.shared.$store
                .map(\.engineUpdateAction)
                .sink { value in
                    self.manageBackgroundTask(value != .off)
                }
                .store(in: &self.updateSettingsCancellables)

            // Disable automatic updates while onboarding.
            AppSettingsV1PersistentStateModel.shared.$store
                .map(\.inOnboarding)
                .sink { onboarding in
                    if onboarding {
                        self.manageBackgroundTask(false)
                    } else {
                        self.manageBackgroundTask(self.getUpdateBehavior() != .off)
                    }
                }
                .store(in: &self.updateSettingsCancellables)

            // Listen for updates to the internal state.
            self.$state
                .sink { [weak self] _ in
                    self?.onInternalStateUpdate()
                }
                .store(in: &self.updateInternalStateCancellables)
        }
    }

    /// Add listeners for settings changes.
    private func manageBackgroundTask(_ enabled: Bool) {
        if enabled {
            backgroundTask = AnyCancellable(BackgroundEventServiceModel.shared.queue
                .schedule(after: .init(.now()), interval: .seconds(60 * 60 * 6), {
                    DispatchQueue.main.async(qos: .background) {
                        self.checkForUpdates(userInitiated: false)
                    }
                }))
        } else {
            backgroundTask?.cancel()
        }
    }

    /// Call functions when the internal state is updated.
    @MainActor private func onInternalStateUpdate() {
        if !userInitiatedCheck {
            return
        }

        let updateBehavior = AppSettingsV1PersistentStateModel.shared.store.engineUpdateAction
        if updateBehavior == .off {
            return
        }

        switch state {
        case .updateAvailable(let update, _, _):
            if updateBehavior == .install {
                update(.update)
            }
        case .noUpdateAvailable, .success, .failure:
            resetState()
            publishStateChange(change: .idle)
        default:
            break
        }
    }

    /// Tell the updater to check for updates.
    /// - Parameter branch: The branch to check for updates on.
    @MainActor public func checkForUpdates(
        branch: EngineVersionsDownloadModel.ReleaseBranch? = nil,
        userInitiated: Bool = false, ignoreCurrentVersion: Bool = false) {
        if !clearStateIfPossible() {
            if userInitiated {
                logger.info("Update check already in progress, switching to user-initiated check.")
                DispatchQueue.main.async {
                    self.userInitiatedCheck = true
                }
            } else {
                logger.warning("Update check already in progress, ignoring request.")
            }
            return
        }

        DispatchQueue.main.async {
            self.userInitiatedCheck = userInitiated
        }

        let branch = AppSettingsV1PersistentStateModel.shared.store.engineReleaseBranch

        DispatchQueue.main.async {
            Task {
                await self.doUpdateCheck(branch: branch, withoutComparingToCurrentVersion: ignoreCurrentVersion)
            }
        }
    }

    /// Clear the internal state if possible.
    private func clearStateIfPossible() -> Bool {
        switch state {
        case .idle, .noUpdateAvailable, .updateAvailable, .readyToInstall, .success, .failure:
            resetState()
            publishStateChange(change: .idle)
            return true
        default:
            return false
        }
    }

    /// Publish a change to the state.
    private func publishStateChange(change: UpdaterState) {
        DispatchQueue.main.async {
            self.state = change
        }
    }

    /// Get the update behavior for the current engine.
    @MainActor private func getUpdateBehavior() -> AppSettingsV1PersistentStateModel.AutoUpdateAction {
        return AppSettingsV1PersistentStateModel.shared.store.engineUpdateAction
    }

    /// Get an artifact by its ID.
    private func getArtifact(byID id: UUID) -> (String, EngineVersionsDownloadModel.Artifact)? {
        guard let versionsFile = versionsFile else {
            return nil
        }

        guard let artifact = versionsFile.artifacts.enumerated().first(where: {
            return UUID(uuidString: $0.element.key) == id
        }) else {
            return nil
        }

        return (artifact.element.key, artifact.element.value)
    }

    /// Reset the internal state.
    private func resetState() {
        versionsFile = nil
        latestVersion = nil
        releaseInfo = nil
    }

    /// Get the current architecture.
    private func getCurrentArchitecture() -> EngineVersionsDownloadModel.BuildArchitecture {
        // Note: If the app is running through Rosetta, the architecture will be x86_64.
        var sysinfo = utsname()
        uname(&sysinfo)

        let machine = withUnsafeBytes(of: &sysinfo.machine) { buffer -> String in
            let data = Data(buffer)
            if let lastIndex = data.lastIndex(where: { $0 != 0 }) {
                return String(data: data[0...lastIndex], encoding: .isoLatin1) ?? "unknown"
            } else {
                return String(data: data, encoding: .isoLatin1) ?? "unknown"
            }
        }

        return machine == "arm64" ? .arm64 : .x64
    }

    /// The updater
    private func doUpdateCheck(branch: EngineVersionsDownloadModel.ReleaseBranch, withoutComparingToCurrentVersion: Bool = false) async {
        resetState()
        logger.info("Checking for updates on branch \(branch.rawValue)...")
        publishStateChange(change: .checkingForUpdates)

        let versionsFileResult = await EngineVersionsDownloadModel.getVersionsFile(for: branch)
        let versionsFile: EngineVersionsDownloadModel.VersionsFile
        switch versionsFileResult {
        case .success(let versions):
            self.versionsFile = versions
            versionsFile = versions
        case .failure(let error):
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: error))
            logger.warning("Failed to get versions file: \(error)")
            return
        }

        // Sort the versions by version number, then by publish date.
        let currentArchitecture = getCurrentArchitecture()
        guard let latestVersion = versionsFile.versions.values.filter({
            $0.builds.first(where: { $0.architecture == currentArchitecture && $0.operatingSystem == .macOS })
                != nil
        }).sorted(by: {
            $0.version == $1.version ? $0.publishDate > $1.publishDate : $0.version > $1.version
        }).first else {
            publishStateChange(change: .noUpdateAvailable(dismiss: {
                self.publishStateChange(change: .idle)
            }))
            logger.error("No versions found in versions file.")
            return
        }

        guard let build = latestVersion.builds.first(where: { $0.architecture == currentArchitecture && $0.operatingSystem == .macOS }) else {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.unexpectedState))
            logger.error("No build found for the current architecture in the latest version. This shouldn't even be possible due to previous checks.")
            return
        }

        self.latestVersion = latestVersion
        self.build = build

        if !withoutComparingToCurrentVersion {
            let currentEngineResult = EngineVersionsDownloadModel.getStoredMetadata()
            let metadata: EngineVersionsDownloadModel.EngineSidecarMetadata
            switch currentEngineResult {
            case .success(let data):
                metadata = data
            case .failure(let error):
                publishStateChange(change: .failure(dismiss: {
                    self.publishStateChange(change: .idle)
                }, error: error))
                logger.debug("Failed to get current engine metadata, this could be because the engine isn't installed.")
                return
            }

            if metadata.version >= latestVersion.version {
                publishStateChange(change: .noUpdateAvailable(dismiss: {
                    self.publishStateChange(change: .idle)
                }))
                logger.debug("No update available because the current engine is up to date.")
                return
            }
        }

        publishStateChange(change: .downloadingReleaseInfo(.initializing))

        // Download the release info.
        guard let releaseInfoArtifact = getArtifact(byID: latestVersion.releaseInfo) else {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.artifactReferenceUnresolved))
            logger.error("Release info artifact reference unresolved: \(latestVersion.releaseInfo.uuidString)")
            return
        }

        let startDate = Date()
        let releaseInfoDataResult = await EngineVersionsDownloadModel.downloadArtifact(
            releaseInfoArtifact.1,
            progress: { total, received in
                self.publishStateChange(change: .downloadingReleaseInfo(
                    .downloading(startDate: startDate, total: total < 0 ? nil : UInt64(total), downloaded: UInt64(received))
                ))
            })
        let releaseInfoData: Data
        switch releaseInfoDataResult {
        case .success(let data):
            releaseInfoData = data
        case .failure(let error):
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: error))
            logger.error("Failed to download release info: \(error)")
            return
        }

        publishStateChange(change: .downloadingReleaseInfo(.verifying))

        // Verify the data's hash.
        let releaseInfoHashMatches = EngineVersionsDownloadModel.verifyChecksum(
            of: releaseInfoArtifact.1,
            with: releaseInfoData
        )
        if !releaseInfoHashMatches {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.hashVerificationFailed(
                releaseInfoArtifact.1.id,
                releaseInfoArtifact.1.hash.value
            )))
            logger.error("Release info hash verification failed: \(releaseInfoArtifact.1.id.uuidString)")
            return
        }

        let releaseInfoResult = EngineVersionsDownloadModel.parseReleaseInfo(from: releaseInfoData)
        let releaseInfo: EngineVersionsDownloadModel.ReleaseInfo
        switch releaseInfoResult {
        case .success(let info):
            releaseInfo = info
        case .failure(let error):
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: error))
            logger.error("Failed to parse release info: \(error)")
            return
        }

        self.releaseInfo = releaseInfo

        publishStateChange(change: .updateAvailable(
            update: { choice in
                if choice == .update {
                    Task { await self.doUpdateDownload() }
                } else {
                    self.resetState()
                    self.publishStateChange(change: .idle)
                }
            },
            version: latestVersion,
            releaseInfo: releaseInfo
        ))
    }

    private func doUpdateDownload() async {
        guard let latestVersion = latestVersion, let build = build else {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.unexpectedState))
            logger.error("Unexpected state: no latest version or build while attempting to download update.")
            return
        }

        publishStateChange(change: .downloadingUpdate(.initializing))

        // Download the update.
        guard let updateArtifact = getArtifact(byID: build.artifact) else {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.artifactReferenceUnresolved))
            logger.error("Update artifact reference unresolved: \(build.artifact.uuidString)")
            return
        }

        let startDate = Date()
        let updateDataResult = await EngineVersionsDownloadModel.downloadArtifact(
            updateArtifact.1,
            progress: { total, received in
                self.publishStateChange(change: .downloadingUpdate(
                    .downloading(startDate: startDate, total: total < 0 ? nil : UInt64(total), downloaded: UInt64(received))
                ))
            })
        let updateData: Data
        switch updateDataResult {
        case .success(let data):
            updateData = data
        case .failure(let error):
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: error))
            logger.error("Failed to download update: \(error)")
            return
        }

        publishStateChange(change: .downloadingUpdate(.verifying))

        // Verify the data's hash.
        let updateHashMatches = EngineVersionsDownloadModel.verifyChecksum(
            of: updateArtifact.1,
            with: updateData
        )
        if !updateHashMatches {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.hashVerificationFailed(
                updateArtifact.1.id,
                updateArtifact.1.hash.value
            )))
            logger.error("Update hash verification failed: \(updateArtifact.1.id.uuidString)")
            return
        }

        publishStateChange(change: .verifyingUpdate)

        // Verify the update's signature.
        let updateSignatureMatchesResult = EngineVersionsDownloadModel.verifySignature(
            for: updateData,
            with: build.signature
        )
        switch updateSignatureMatchesResult {
        case .success(let matches):
            if !matches {
                publishStateChange(change: .failure(dismiss: {
                    self.publishStateChange(change: .idle)
                }, error: EngineUpdateError.signatureVerificationFailed(
                    updateArtifact.1.id,
                    build.signature.publicKey,
                    build.signature.value
                )))
                logger.error("Update signature verification failed: \(updateArtifact.1.id.uuidString)")
                return
            }
        case .failure(let error):
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: error))
            logger.error("Failed to verify update signature: \(error)")
            return
        }

        // Write the file to the temporary directory.
        guard let temporaryDirectory = DirectoriesUtility.temporaryDirectory else {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.urlCreationError))
            logger.error("Failed to get temporary directory.")
            return
        }
        let temporaryFileURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        if !FileManager.default.fileExists(atPath: temporaryDirectory.path()) {
            do {
                try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            } catch {
                publishStateChange(change: .failure(dismiss: {
                    self.publishStateChange(change: .idle)
                }, error: EngineUpdateError.pathCreationError(error)))
                logger.error("Failed to create temporary directory: \(error)")
                return
            }
        }

        do {
            try updateData.write(to: temporaryFileURL)
        } catch {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.filesystemError(error)))
        }

        // If a tarball was already downloaded, delete it.
        if let downloadedTarball = downloadedTarball {
            try? FileManager.default.removeItem(at: downloadedTarball)
        }

        self.downloadedTarball = temporaryFileURL
        self.downloadedLatestVersion = latestVersion
        self.downloadedReleaseInfo = releaseInfo
        self.downloadedBuild = build

        publishStateChange(change: .readyToInstall(
            install: { choice in
                if choice == .update {
                    Task { await self.doUpdateInstall() }
                } else {
                    // Do nothing, the update will install itself at close if available.
                    self.publishStateChange(change: .idle)
                }
            }
        ))
    }

    private func doUpdateInstall() async {
        guard let latestVersion = downloadedLatestVersion,
              let releaseInfo = downloadedReleaseInfo,
              let build = downloadedBuild,
              let downloadedTarball = downloadedTarball else {
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: EngineUpdateError.unexpectedState))
            logger.warning("Unexpected state: no latest version, build, or downloaded tarball while attempting to install update.")
            return
        }

        publishStateChange(change: .installing)

        let installResult = await EngineVersionsDownloadModel.installUpdatePackage(at: downloadedTarball)
        switch installResult {
        case .success:
            publishStateChange(change: .success(dismiss: {
                self.publishStateChange(change: .idle)
            }))
        case .failure(let error):
            publishStateChange(change: .failure(dismiss: {
                self.publishStateChange(change: .idle)
            }, error: error))
            try? FileManager.default.removeItem(at: downloadedTarball)
            self.downloadedTarball = nil
            self.downloadedLatestVersion = nil
            self.downloadedReleaseInfo = nil
            self.downloadedBuild = nil
            return
        }

        // Delete the downloaded tarball.
        try? FileManager.default.removeItem(at: downloadedTarball)
        self.downloadedTarball = nil
        self.downloadedLatestVersion = nil
        self.downloadedReleaseInfo = nil
        self.downloadedBuild = nil

        // Update the engine metadata.
        let result = EngineVersionsDownloadModel.setStoredMetadata(.init(
            version: latestVersion.version,
            versionID: latestVersion.id,
            versionPublishDate: latestVersion.publishDate,
            versionUpdatePriority: latestVersion.updatePriority,
            releaseInfo: releaseInfo,
            buildOperatingSystem: build.operatingSystem,
            buildArchitecture: build.architecture,
            buildSignature: build.signature
        ))
        switch result {
        case .success:
            break
        case .failure(let error):
            logger.warning("Failed to update engine metadata: \(error)")
        }

        // Reset the state.
        resetState()
        publishStateChange(change: .success(dismiss: {
            self.publishStateChange(change: .idle)
        }))
    }
}
