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

    override init() {
        super.init()
    }
    
    private func restoreActiveRootWindow() {
        NSApplication.shared.windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    /// Listen for events
    @MainActor private func listenEvents() {
        self.cancellables.removeAll()

        SparkleUpdateControllerModel.shared.$state.sink(receiveValue: { [self] value in
            switch value {
            case .updateAvailable, .checkingForUpdates, .readyToRelaunch, .noUpdateAvailable:
                restoreActiveRootWindow()
            default: ()
            }
        }).store(in: &cancellables)
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)

        Task {
            listenEvents()
        }
    }

    public func applicationWillFinishLaunching(_ notification: Notification) {
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if hasVisibleWindows { return true }
        restoreActiveRootWindow()
        return true
    }
}
