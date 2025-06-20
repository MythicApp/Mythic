//
//  AppDelegate.swift
//  Mythic
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
    
    private enum CurrentRootWindow {
        case none
        case onboarding(OnboardingWindow)
        case hub(HubWindow)
    }
    private var currentRootWindow: CurrentRootWindow = .none
    private var aboutWindow = AboutWindow()
    
    private var appMenu = AppMenuController()

    override init() {
        super.init()
    }
    
    @MainActor private func restoreActiveRootWindow() {
        switch currentRootWindow {
        case .hub(let hubWindow):
            hubWindow.show()
        case .onboarding(let onboardingWindow):
            onboardingWindow.show()
        default: ()
        }
    }
    
    @MainActor private func showRootWindow(inOnboarding: Bool) {
        if inOnboarding {
            if case .onboarding(let onboardingWindow) = currentRootWindow {
                onboardingWindow.show()
            }
            let onboardingWindow = OnboardingWindow()
            onboardingWindow.show()
            currentRootWindow = .onboarding(onboardingWindow)
        } else {
            if case .hub(let hubWindow) = currentRootWindow {
                hubWindow.show()
            }
            let hubWindow = HubWindow()
            hubWindow.show()
            currentRootWindow = .hub(hubWindow)
        }
    }

    /// Listen for events
    @MainActor private func listenEvents() {
        self.cancellables.removeAll()

        AppSettingsV1PersistentStateModel.shared.$store.map(\.inOnboarding).sink(receiveValue: { [self] inOnboarding in
            showRootWindow(inOnboarding: inOnboarding)
            appMenu.setRestartOnboardingEnabled(!inOnboarding)
        }).store(in: &cancellables)
    
        appMenu.restartOnboardingPublisher.sink(receiveValue: {
            if AppSettingsV1PersistentStateModel.shared.store.inOnboarding == true { return }
            AppSettingsV1PersistentStateModel.shared.store.inOnboarding = true
        }).store(in: &cancellables)
    
        appMenu.checkForUpdatesPublisher.sink(receiveValue: {
            SparkleUpdateControllerModel.shared.checkForUpdates(userInitiated: true)
        }).store(in: &cancellables)
        
        appMenu.showAboutPublisher.sink(receiveValue: {
            self.aboutWindow.show()
        }).store(in: &cancellables)
        
        SparkleUpdateControllerModel.shared.$state.sink(receiveValue: { [self] value in
            if !SparkleUpdateControllerModel.shared.userInitiatedCheck { return }
            switch value {
            case .updateAvailable, .checkingForUpdates, .readyToRelaunch, .noUpdateAvailable:
                restoreActiveRootWindow()
            default: ()
            }
        }).store(in: &cancellables)
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        NSWindow.allowsAutomaticWindowTabbing = false

        Task {
            listenEvents()
        }
    }

    public func applicationWillFinishLaunching(_ notification: Notification) {
//        showRootWindow(inOnboarding: AppSettingsV1PersistentStateModel.shared.store.inOnboarding)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if hasVisibleWindows { return true }
        restoreActiveRootWindow()
        return true
    }
}
