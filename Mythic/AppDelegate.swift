//
//  AppDelegate.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/2/2024.
//

// Copyright © 2023-2025 vapidinfinity

import OSLog

import SemanticVersion
import SwiftUI
import SwordRPC
import UserNotifications

import Firebase
import FirebaseCore
import FirebaseCrashlytics

// TODO: modularise
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // MARK: Firebase Configuration
        // Use the Firebase library to configure APIs.
        FirebaseApp.configure()

        FirebaseConfiguration.shared.setLoggerLevel(.min)

        setenv("CX_ROOT", Bundle.main.bundlePath, 1)

        // MARK: Register Defaults
        UserDefaults.standard.register(defaults: [
            "discordRPC": true,
            "engineAutomaticallyChecksForUpdates": true,
            "quitOnAppClose": false,
            // FIXME: dangerous but necessary force-unwrap
            // FIXME: very rarely, some users may not have write access to appGames.
            // FIXME: e.g. MGM cases
            "installBaseURL": Bundle.appGames!
        ])

        Task {
            try? await GameDataStore.shared.refreshFromStorefronts()
        }

        Migrator.fullMigration()

        // MARK: Start metadata update cycle for Legendary
        Task(priority: .utility) {
            while true {
                await MainActor.run(body: { Legendary.updateMetadata() })
                try? await Task.sleep(for: .seconds(5 * 60))
            }
        }

        // MARK: Autosync Legendary cloud saves
        Task(priority: .utility) {
            try? await Legendary.execute(arguments: ["-y", "sync-saves"])
        }

        // MARK: DiscordRPC Delegate Ininitialisation & Connection
        discordRPC.delegate = self
        if UserDefaults.standard.bool(forKey: "discordRPC"), discordRPC.isDiscordInstalled {
            _ = discordRPC.connect()
        }

        // MARK: Applications folder disclaimer
#if !DEBUG
        if !Bundle.main.bundleURL.pathComponents.contains("Applications") {
            let alert = NSAlert()
            alert.messageText = String(localized: "Mythic has detected it's running outside of the applications folder.")
            alert.informativeText = String(localized: "It's recommended to move Mythic into the Applications folder on your device.")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "OK"))

            if let window = NSApp.windows.first {
                alert.beginSheetModal(for: window)
            }
        }
#endif // !DEBUG

        // MARK: Notification Authorisation Request and Delegation Setting
        UNUserNotificationCenter.current().delegate = self
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus != .authorized else { return }

            do {
                try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                Logger.app.error("Unable to request notification authorization: \(error)")
            }
        }

        // MARK: Engine update alert chain
        Task(priority: .background) { @MainActor in
            guard UserDefaults.standard.bool(forKey: "engineAutomaticallyChecksForUpdates"),
                  (try? await Engine.isUpdateAvailable()) == true else { return }

            let latestVersion = (try? await Engine.getLatestRelease())?.version.description ?? String(localized: "Unknown")
            let currentVersion = await Engine.installedVersion?.description ?? String(localized: "an unknown version", comment: "Of Mythic Engine")

            let alert = NSAlert()
            alert.messageText = String(localized: "Mythic Engine update available.")
            alert.informativeText = String(localized: """
                A new version of Mythic Engine (\(latestVersion)) has released.
                You're currently using \(currentVersion).
                """)
            alert.addButton(withTitle: String(localized: "Update"))
            alert.addButton(withTitle: String(localized: "Cancel"))

            guard let window = NSApp.windows.first else { return }

            alert.beginSheetModal(for: window) { response in
                guard case .alertFirstButtonReturn = response else { return }

                let confirmation = NSAlert()
                confirmation.messageText = String(localized: "Are you sure you want to update now?")
                confirmation.informativeText = String(localized: """
                    This will remove the current version of Mythic Engine.
                    The latest version will be installed the next time you attempt to launch a Windows® game.
                    """)
                confirmation.addButton(withTitle: String(localized: "Update"))
                confirmation.addButton(withTitle: String(localized: "Cancel"))

                confirmation.beginSheetModal(for: window) { response in
                    guard case .alertFirstButtonReturn = response else { return }

                    Task(priority: .userInitiated) {
                        do {
                            try await Engine.remove()

                            let successAlert = NSAlert()
                            successAlert.alertStyle = .informational
                            successAlert.messageText = String(localized: "Successfully removed Mythic Engine.")
                            successAlert.informativeText = String(localized: "The latest version will be installed the next time you attempt to launch a Windows® game.")
                            successAlert.addButton(withTitle: String(localized: "OK"))

                            await successAlert.beginSheetModal(for: window)
                        } catch {
                            let errorAlert = NSAlert()
                            errorAlert.alertStyle = .critical
                            errorAlert.messageText = String(localized: "Unable to remove Mythic Engine.")
                            errorAlert.informativeText = error.localizedDescription
                            errorAlert.addButton(withTitle: String(localized: "OK"))

                            await errorAlert.beginSheetModal(for: window)
                        }
                    }
                }
            }
        }

        // Version-specific app launch counter
        if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            var launchCountDictionary = UserDefaults.standard.dictionary(forKey: "launchCount") as? [String: Int] ?? .init()
            launchCountDictionary[shortVersion, default: 0] += 1
            UserDefaults.standard.set(launchCountDictionary, forKey: "launchCount")
        }
    }

    func applicationDidBecomeActive(_: Notification) {
        _ = discordRPC.connect()
    }

    func applicationDidResignActive(_: Notification) {
        discordRPC.disconnect()
    }

    @MainActor func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !GameOperationManager.shared.queue.isEmpty else { return .terminateNow }

        let alert: NSAlert = .init()
        alert.messageText = String(localized: "Are you sure you want to quit?")
        alert.informativeText = String(localized: "Mythic is still modifying games.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Quit"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        if let window = sender.windows.first {
            alert.beginSheetModal(for: window) { response in
                if case .alertFirstButtonReturn = response {
                    sender.reply(toApplicationShouldTerminate: true)
                } else {
                    sender.reply(toApplicationShouldTerminate: false)
                }
            }
        }

        return .terminateLater
    }

    @MainActor
    func applicationWillTerminate(_: Notification) {
        if UserDefaults.standard.bool(forKey: "quitOnAppClose") {
            try? Wine.killAll()
        }

        Task.detached(priority: .userInitiated) {
            await GameOperationManager.shared.cancelAllOperations()
        }

        Task.detached(priority: .userInitiated) {
            await Legendary.RunningCommands.shared.stopAll()
        }

        Task.detached(priority: .userInitiated) {
            try? await Legendary.execute(arguments: ["cleanup"])
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {}

extension AppDelegate: SwordRPCDelegate {
    func swordRPCDidConnect(_ rpc: SwordRPC) {
        rpc.setPresence({
            var presence: RichPresence = .init()
            presence.details = "Idling in Mythic"
            presence.state = "Idle"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"

            return presence
        }())
    }
}
