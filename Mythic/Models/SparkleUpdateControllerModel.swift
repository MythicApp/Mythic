//
//  SparkleUpdateControllerModel.swift
//  Mythic
//
//  Created by Josh on 11/14/24.
//

import Foundation
import Combine
import Sparkle

public final class SparkleUpdateControllerModel: NSObject, SPUUserDriver, ObservableObject {
    /// The shared instance of the Sparkle updater events.
    public static let shared = SparkleUpdateControllerModel()

    private let logger = AppLoggerModel(category: SparkleUpdateControllerModel.self)

    /// The Sparkle updater.
    private var sparkleUpdater: SPUUpdater?

    /// Choice to update.
    public enum UpdateChoice {
        case update
        case dismiss
    }

    /// Download progress.
    public struct DownloadProgress {
        public let started: Date
        public var total: UInt64
        public var completed: UInt64
    }

    /// Extract progress.
    public struct ExtractProgress {
        public let started: Date
        public var progress: Double
    }

    /// The state of an sparkle update.
    public enum UpdateState {
        public var stateType: Int {
            switch self {
            case .idle: return 0
            case .checkingForUpdates: return 1
            case .updateAvailable: return 2
            case .noUpdateAvailable: return 3
            case .initializingUpdate: return 4
            case .downloadingUpdate: return 5
            case .extractingUpdate: return 6
            case .readyToRelaunch: return 7
            case .installingUpdate: return 8
            case .error: return 9
            }
        }

        case idle
        case checkingForUpdates(cancel: () -> Void)
        case updateAvailable(choice: (UpdateChoice) -> Void, appcast: SUAppcastItem)
        case noUpdateAvailable(acknowledge: () -> Void)
        case initializingUpdate
        case downloadingUpdate(cancel: () -> Void, progress: DownloadProgress)
        case extractingUpdate(progress: ExtractProgress)
        case readyToRelaunch(acknowledge: (UpdateChoice) -> Void)
        case installingUpdate
        case error(acknowledge: () -> Void, error: Error)
    }

    /// The current state of the update.
    @Published public private(set) var state: UpdateState = .idle
    /// If the check was initiated by the user.
    @Published public private(set) var userInitiatedCheck: Bool = false
    /// The cancellables for the update state.
    private var updateSettingsCancellables: Set<AnyCancellable> = []
    /// The current background task.
    private var backgroundTask: AnyCancellable?

    /// Initialize the Sparkle updater.
    public override init() {
        super.init()

        let updaterController = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: self,
            delegate: nil
        )
        self.sparkleUpdater = updaterController

        updaterController.automaticallyChecksForUpdates = false
        updaterController.automaticallyDownloadsUpdates = false
        do { try updaterController.start() } catch {
            logger.error("Sparkle failed to start: \(error.localizedDescription).")
        }

        DispatchQueue.main.async {
            self.manageBackgroundTask(AppSettingsV1PersistentStateModel.shared.store.sparkleUpdateAction != .off)
            AppSettingsV1PersistentStateModel.shared.$store
                .map(\.sparkleUpdateAction)
                .sink { value in
                    self.manageBackgroundTask(value != .off)
                }
                .store(in: &self.updateSettingsCancellables)
        }
    }

    /// Add listener for the update state.
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

    /// System controlled update.
    @MainActor private func onBackgroundUpdate() {
        checkForUpdates(userInitiated: false)
    }

    /// Clear any existing update state.
    public func clearState() -> Bool {
        switch state {
        case .idle:
            return true
        case .checkingForUpdates(let cancel):
            cancel()
        case .updateAvailable(let choice, _):
            choice(.dismiss)
        case .noUpdateAvailable(let acknowledge):
            acknowledge()
        case .downloadingUpdate(let cancel, _):
            cancel()
        case .extractingUpdate:
            return false
        case .initializingUpdate:
            return false
        case .readyToRelaunch(let acknowledge):
            acknowledge(.dismiss)
        case .installingUpdate:
            return false
        case .error(let acknowledge, _):
            acknowledge()
        }

        return true
    }

    /// Force clear the current state.
    public func forceClearState() {
        state = .idle
    }

    /// Check for updates
    /// - Parameter userInitiated: If the check was initiated by the user.
    @MainActor public func checkForUpdates(userInitiated: Bool = false) {
        guard let updater = sparkleUpdater, !updater.sessionInProgress else {
            logger.info("\(userInitiated ? "User-initiated" : "Automatic") update check ignored due to in-progress update session.")
            if userInitiated {
                userInitiatedCheck = true
            }
            return
        }

        logger.info("\(userInitiated ? "User-initiated" : "Automatic") update check initiated...")
        _ = clearState()
        userInitiatedCheck = userInitiated
        updater.checkForUpdates()
    }

    /// Get the updater action
    private func getUpdaterAction() -> AppSettingsV1PersistentStateModel.AutoUpdateAction {
        var action: AppSettingsV1PersistentStateModel.AutoUpdateAction = .off
        DispatchQueue.main.sync {
            action = AppSettingsV1PersistentStateModel.shared.store.sparkleUpdateAction
        }
        return action
    }

    /// Get the updater action
    private func preferSilent() -> Bool {
        var action: Bool = false
        DispatchQueue.main.sync {
            action = !AppSettingsV1PersistentStateModel.shared.store.inOnboarding
        }
        return action
    }

    /// Initialize the settings for the updater.
    /// Implementation of `SPUUserDriver` protocol.
    public func show(_ request: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
        logger.debug("Update permission request received.")
        return .init(
            automaticUpdateChecks: false,
            sendSystemProfile: false
        )
    }

    /// A checking for updates event initiated by the user.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        logger.debug("Update check initiated.")
        state = .checkingForUpdates {
            cancellation()
        }
    }

    /// An update is available.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                                  reply: @escaping (SPUUserUpdateChoice) -> Void) {
        logger.debug("Update found: \(appcastItem.displayVersionString.isEmpty ? "unknown" : appcastItem.displayVersionString).")

        if !userInitiatedCheck && getUpdaterAction() == .install {
            reply(.install)
            self.state = .initializingUpdate
            return
        } else if getUpdaterAction() == .check && !preferSilent() {
            userInitiatedCheck = true
        }

        self.state = .updateAvailable(choice: { choice in
            switch choice {
            case .update:
                reply(.install)
                self.state = .initializingUpdate
            case .dismiss:
                reply(.dismiss)
                self.state = .idle
            }
        }, appcast: appcastItem)
    }

    /// Never needed.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        logger.debug("Release notes received.")
    }

    /// Release notes failed to load.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        logger.error("Failed to download release notes: \(error.localizedDescription).")

        if !userInitiatedCheck {
            self.state = .idle
            return
        }

        state = .error(acknowledge: {
            self.state = .idle
        }, error: error)
    }

    /// No update available.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        logger.info("No update available.")

        if !userInitiatedCheck {
            acknowledgement()
            self.state = .idle
            return
        }

        state = .noUpdateAvailable(acknowledge: {
            acknowledgement()
            self.state = .idle
        })
    }

    /// An error occurred.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        logger.error("Updater error: \(error.localizedDescription).")

        if !userInitiatedCheck {
            acknowledgement()
            self.state = .idle
            return
        }

        state = .error(acknowledge: {
            acknowledgement()
            self.state = .idle
        }, error: error)
    }

    /// An update is downloading.
    /// Implementation of `SPUUserDriver` protocol.
    public func showDownloadInitiated(cancellation: @escaping () -> Void) {
        logger.debug("Update download initiated.")
        state = .downloadingUpdate(cancel: {
            cancellation()
            self.state = .idle
        }, progress: .init(started: .init(), total: 0, completed: 0))
    }

    /// An update is downloading.
    /// Implementation of `SPUUserDriver` protocol.
    public func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        guard case .downloadingUpdate(let cancel, var progress) = state else {
            return
        }

        progress.total = expectedContentLength
        state = .downloadingUpdate(cancel: cancel, progress: progress)
    }

    /// An update is downloading.
    /// Implementation of `SPUUserDriver` protocol.
    public func showDownloadDidReceiveData(ofLength length: UInt64) {
        guard case .downloadingUpdate(let cancel, var progress) = state else {
            return
        }

        progress.completed += length
        state = .downloadingUpdate(cancel: cancel, progress: progress)
    }

    /// An update is extracting.
    /// Implementation of `SPUUserDriver` protocol.
    public func showDownloadDidStartExtractingUpdate() {
        logger.debug("Update download complete; extracting...")
        state = .extractingUpdate(progress: .init(started: .init(), progress: 0))
    }

    /// An update is extracting.
    /// Implementation of `SPUUserDriver` protocol.
    public func showExtractionReceivedProgress(_ progress: Double) {
        guard case .extractingUpdate(let currentProgress) = state else {
            return
        }

        state = .extractingUpdate(progress: .init(started: currentProgress.started, progress: progress))
    }

    /// An update is ready to install.
    /// Implementation of `SPUUserDriver` protocol.
    public func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        logger.debug("Update ready to install.")

        if !userInitiatedCheck && !preferSilent() {
            userInitiatedCheck = true
        }

        state = .readyToRelaunch { choice in
            switch choice {
            case .update:
                reply(.install)
                self.state = .installingUpdate
            case .dismiss:
                reply(.dismiss)
                self.state = .idle
            }
        }
    }

    /// An update is installing.
    /// Implementation of `SPUUserDriver` protocol.
    public func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                                     retryTerminatingApplication: @escaping () -> Void) {
        logger.debug("Update installing...")
        state = .installingUpdate
    }

    /// Never needed.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    /// Focus the updater.
    /// Implementation of `SPUUserDriver` protocol.
    public func showUpdateInFocus() {}

    /// Dismiss the updater.
    /// Implementation of `SPUUserDriver` protocol.
    public func dismissUpdateInstallation() {
        guard userInitiatedCheck else {
            self.state = .idle
            return
        }

        if case .checkingForUpdates = state {
            // No updates were found.
            state = .noUpdateAvailable {
                self.state = .idle
            }
        }
    }
}
