//
//  AppDelegate.swift
//  Mythic
//
//  Created by Josh on 10/23/24.
//

import Foundation
import AppKit
import Combine
import SemanticVersion

public class AppDelegate: NSObject, NSApplicationDelegate {
    public static let shared = AppDelegate()

    public static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Mythic"
    public static let applicationVersion = SemanticVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                                           as? String ?? "0.0.0") ?? .init(0, 0, 0)
    public static let applicationBundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Application"

    private let logger = AppLoggerModel(category: AppDelegate.self)

    private var cancellables: Set<AnyCancellable> = []

    private let appMenuController = AppMenuController()

    private enum RootWindowController {
        case none
        case setup(SetupWindowController)
        case hub(HubWindowController)
    }
    private var rootWindowController: RootWindowController = .none

    override init() {
        super.init()
    }

    /// Listen for events
    @MainActor private func listenEvents() {
        cancellables.removeAll()

        // Listen for onboarding state changes
        AppSettingsV1PersistentStateModel.shared.$store.map(\.inOnboarding).sink(receiveValue: { [self] inOnboarding in
            if inOnboarding {
                logger.info("Onboarding state active; switching to setup window.")
                setupWindowController().show()
                appMenuController.setRestartOnboardingVisibility(false)
            } else {
                logger.info("Onboarding state inactive; switching to main window.")
                hubWindowController().show()
                appMenuController.setRestartOnboardingVisibility(true)
            }
        }).store(in: &cancellables)

        SparkleUpdateControllerModel.shared.$state.sink(receiveValue: { [self] value in
            switch value {
            case .updateAvailable, .checkingForUpdates, .readyToRelaunch, .noUpdateAvailable:
                restoreActiveRootWindow()
            default: ()
            }
        }).store(in: &cancellables)
    }

    /// Get the setup window or switch to it.
    private func setupWindowController() -> SetupWindowController {
        switch rootWindowController {
        case .setup(let controller):
            return controller
        default:
            let setupWindowController = SetupWindowController()
            rootWindowController = .setup(setupWindowController)
            return setupWindowController
        }
    }

    /// Get the main window or switch to it.
    private func hubWindowController() -> HubWindowController {
        switch rootWindowController {
        case .hub(let controller):
            return controller
        default:
            let hubWindowController = HubWindowController()
            rootWindowController = .hub(hubWindowController)
            return hubWindowController
        }
    }

    /// Restore the active main window.
    private func restoreActiveRootWindow() {
        switch rootWindowController {
        case .hub(let controller):
            controller.show()
        case .setup(let controller):
            controller.show()
        default: ()
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)

        Task {
            listenEvents()
        }
    }

    public func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.mainMenu = appMenuController.create(delegate: self, app: NSApplication.shared)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if hasVisibleWindows { return true }
        restoreActiveRootWindow()

        return true
    }
}
