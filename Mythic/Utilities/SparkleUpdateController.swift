//
//  SparkleUpdateController.swift
//  Mythic
//
//  Created by Josh on 11/14/24.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import Combine
import Sparkle
import OSLog

final class SparkleUpdateController: NSObject, SPUUserDriver, ObservableObject {
    @MainActor static let shared: SparkleUpdateController = .init()

    private let log: Logger = .custom(category: "SparkleUpdaterController")

    private var sparkleUpdater: SPUUpdater?

    @Published private(set) var state: UpdateState = .idle
    @Published private(set) var userInitiatedCheck: Bool = false

    private var updateSettingsCancellables: Set<AnyCancellable> = []
    private var backgroundTask: AnyCancellable?
    private let backgroundQueue: DispatchQueue = .init(label: "BackgroudEventService", qos: .background)

    override init() {
        super.init()

        let updaterController: SPUUpdater = .init(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: self,
            delegate: nil
        )
        self.sparkleUpdater = updaterController

        updaterController.automaticallyChecksForUpdates = false
        updaterController.automaticallyDownloadsUpdates = false
        do { try updaterController.start() } catch {
            log.error("Sparkle failed to start: \(error.localizedDescription).")
        }

        self.manageBackgroundTask(sparkleUpdateAction != .off)
    }

    private func manageBackgroundTask(_ enabled: Bool) {
        if enabled {
            backgroundTask = AnyCancellable(
                backgroundQueue.schedule(
                    after: .init(.now()),
                    interval: .seconds(60 * 60 * 6)
                ) {
                    Task { @MainActor in
                        SparkleUpdateController.shared.checkForUpdates(userInitiated: false)
                    }
                }
            )
        } else {
            backgroundTask?.cancel()
        }
    }

    func clearState() -> Bool {
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

    func checkForUpdates(userInitiated: Bool = false) {
        guard let updater = sparkleUpdater, !updater.sessionInProgress else {
            log.info("\(userInitiated ? "User-initiated" : "Automatic") update check ignored due to in-progress update session.")
            if userInitiated {
                userInitiatedCheck = true
            }
            return
        }

        log.info("\(userInitiated ? "User-initiated" : "Automatic") update check initiated...")
        _ = clearState()
        userInitiatedCheck = userInitiated
        updater.checkForUpdates()
    }

    private var sparkleUpdateAction: AutoUpdateAction {
        if Thread.isMainThread {
            var action: AutoUpdateAction = .off
            MainActor.assumeIsolated {
                action = (try? UserDefaults.standard.decodeAndGet(AutoUpdateAction.self, forKey: "sparkleUpdateAction")) ?? .install
            }
            return action
        }
        var action: AutoUpdateAction = .off
        DispatchQueue.main.sync {
            action = (try? UserDefaults.standard.decodeAndGet(AutoUpdateAction.self, forKey: "sparkleUpdateAction")) ?? .install
        }
        return action
    }

    private func preferSilent() -> Bool {
        if Thread.isMainThread {
            var action: Bool = false
            MainActor.assumeIsolated {
                action = !UserDefaults.standard.bool(forKey: "isOnboardingPresented")
            }
            return action
        }
        var action: Bool = false
        DispatchQueue.main.sync {
            action = !UserDefaults.standard.bool(forKey: "isOnboardingPresented")
        }
        return action
    }

    func show(_ request: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
        log.debug("Update permission request received.")
        return .init(
            automaticUpdateChecks: false,
            sendSystemProfile: false
        )
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        log.debug("Update check initiated.")
        state = .checkingForUpdates {
            cancellation()
        }
    }

    func showUpdateFound(with appcastItem: SUAppcastItem,
                         state: SPUUserUpdateState,
                         reply: @escaping (SPUUserUpdateChoice) -> Void) {
        log.debug("Update found: \(appcastItem.displayVersionString.isEmpty ? "unknown" : appcastItem.displayVersionString).")

        if !userInitiatedCheck && sparkleUpdateAction == .install {
            reply(.install)
            self.state = .initializingUpdate
            return
        } else if sparkleUpdateAction == .check && !preferSilent() {
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

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        log.debug("Release notes received.")
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        log.error("Failed to download release notes: \(error.localizedDescription).")

        if !userInitiatedCheck {
            self.state = .idle
            return
        }

        state = .error(acknowledge: {
            self.state = .idle
        }, error: error)
    }

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        log.info("No update available.")

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

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        log.error("Updater error: \(error.localizedDescription).")

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

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        log.debug("Update download initiated.")
        state = .downloadingUpdate(cancel: {
            cancellation()
            self.state = .idle
        }, progress: .init(started: .init(), total: 0, completed: 0))
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        guard case .downloadingUpdate(let cancel, var progress) = state else { return }

        progress.total = expectedContentLength
        state = .downloadingUpdate(cancel: cancel, progress: progress)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        guard case .downloadingUpdate(let cancel, var progress) = state else { return }

        progress.completed += length
        state = .downloadingUpdate(cancel: cancel, progress: progress)
    }

    func showDownloadDidStartExtractingUpdate() {
        log.debug("Update download complete; extracting...")
        state = .extractingUpdate(progress: .init(started: .init(), progress: 0))
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        guard case .extractingUpdate(let currentProgress) = state else { return }

        state = .extractingUpdate(progress: .init(started: currentProgress.started, progress: progress))
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        log.debug("Update ready to install.")

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

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                              retryTerminatingApplication: @escaping () -> Void) {
        log.debug("Update installing...")
        state = .installingUpdate
        if !applicationTerminated {
            retryTerminatingApplication()
        }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {  }

    func dismissUpdateInstallation() {
        guard userInitiatedCheck else {
            self.state = .idle
            return
        }

        if case .checkingForUpdates = state {
            state = .noUpdateAvailable {
                self.state = .idle
            }
        }
    }
}

extension SparkleUpdateController {
    enum UpdateChoice {
        case update
        case dismiss
    }

    struct DownloadProgress {
        let started: Date
        var total: UInt64
        var completed: UInt64
    }

    struct ExtractProgress {
        let started: Date
        var progress: Double
    }

    enum UpdateState {
        var stateType: Int {
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

    enum AutoUpdateAction: String, Sendable, Codable, Hashable {
        case off
        case check
        case install
    }
}
