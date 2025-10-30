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
class AppDelegate: NSObject, NSApplicationDelegate { // https://arc.net/l/quote/zyfjpzpn

    public static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Mythic"
    public static let applicationVersion = SemanticVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                                           as? String ?? "0.0.0") ?? .init(0, 0, 0)
    public static let applicationBundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Application"

    func applicationDidFinishLaunching(_: Notification) {
        // Use the Firebase library to configure APIs.
        FirebaseApp.configure()

        setenv("CX_ROOT", Bundle.main.bundlePath, 1)

        defaults.register(defaults: [
            "discordRPC": true,
            "engineAutomaticallyChecksForUpdates": true,
            "quitOnAppClose": false
        ])

        Migrator.migrateFromOldBottleFormatIfNecessary()
        Migrator.migrateBottleSchemeToContainerSchemeIfNecessary()
        
        // MARK: Container cleanup in the event of external deletion

        Wine.containerURLs = Wine.containerURLs.filter { files.fileExists(atPath: $0.path(percentEncoded: false)) }

        Task {
            await Migrator.updateContainerScalingIfNecessary()
        }
        Migrator.migrateEpicFolderNaming()

        // MARK: Start metadata update cycle for Epic Games.

        Task(priority: .utility) { @MainActor in
            Legendary.updateMetadata()

            Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { _ in
                Task(priority: .utility) { @MainActor in
                    Legendary.updateMetadata()
                }
            }
        }

        // MARK: Autosync Epic savegames

        Task(priority: .utility) {
            try? await Legendary.execute(arguments: ["-y", "sync-saves"])
        }

        // MARK: DiscordRPC Delegate Ininitialisation & Connection

        discordRPC.delegate = self
        if defaults.bool(forKey: "discordRPC"), discordRPC.isDiscordInstalled {
            _ = discordRPC.connect()
        }

        // MARK: Applications folder disclaimer

        // TODO: possibly turn this into an onboarding-style message.
#if !DEBUG
        let currentAppURL = Bundle.main.bundleURL
        let optimalAppURL = FileLocations.globalApplications?.appendingPathComponent(currentAppURL.lastPathComponent)

        // MARK: Move to Applications

        if !currentAppURL.pathComponents.contains("Applications") {
            let alert = NSAlert()

            alert.messageText = String(localized: "Move Mythic to the Applications folder?")
            alert.informativeText = String(localized: "Mythic has detected it's running outside of the applications folder.")
            alert.addButton(withTitle: String(localized: "Move"))
            alert.addButton(withTitle: String(localized: "Cancel"))

            if let window = NSApp.windows.first, let optimalAppURL = optimalAppURL {
                alert.beginSheetModal(for: window) { response in
                    if case .alertFirstButtonReturn = response {
                        do {
                            _ = try files.replaceItemAt(optimalAppURL, withItemAt: currentAppURL)
                            workspace.open(optimalAppURL)
                        } catch {
                            Logger.file.error("Unable to move Mythic to Applications: \(error)")

                            let error = NSAlert()
                            error.messageText = String(localized: "Unable to move Mythic to \"\(optimalAppURL.deletingLastPathComponent().prettyPath())\".")
                            error.addButton(withTitle: String(localized: "Quit"))

                            error.beginSheetModal(for: window) { response in
                                if case .alertFirstButtonReturn = response {
                                    exit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
#endif // !DEBUG

        // MARK: Notification Authorisation Request and Delegation Setting

        notifications.delegate = self
        notifications.getNotificationSettings { settings in
            guard settings.authorizationStatus != .authorized else { return }

            notifications.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
                guard error == nil else {
                    Logger.app.error("Unable to request notification authorization: \(error!.localizedDescription)")
                    return
                }
            }
        }

        Task(priority: .background) { @MainActor in
            if defaults.bool(forKey: "engineAutomaticallyChecksForUpdates"),
               (try? await Engine.isUpdateAvailable()) == true {
                let alert = NSAlert()

                alert.messageText = String(localized: "Mythic Engine update available.")
                alert.informativeText = String(localized: """
                    A new version of Mythic Engine (\((try? await Engine.getLatestRelease())?.version.description ?? String(localized: "Unknown")) has released.
                    You're currently using \(await Engine.installedVersion?.description ?? String(localized: "an unknown version", comment: "Of Mythic Engine")).
                    """)

                alert.addButton(withTitle: String(localized: "Update"))
                alert.addButton(withTitle: String(localized: "Cancel"))

                if let window = NSApp.windows.first {
                    alert.beginSheetModal(for: window) { response in
                        if case .alertFirstButtonReturn = response {
                            let confirmation = NSAlert()
                            confirmation.messageText = String(localized: "Are you sure you want to update now?")

                            confirmation.informativeText = String(localized: """
                                This will remove the current version of Mythic Engine.
                                The latest version will be installed the next time you attempt to launch a Windows® game.
                                """)

                            confirmation.addButton(withTitle: String(localized: "Update"))
                            confirmation.addButton(withTitle: String(localized: "Cancel"))

                            confirmation.beginSheetModal(for: window) { response in
                                if case .alertFirstButtonReturn = response {
                                    Task(priority: .userInitiated) {
                                        do {
                                            try await Engine.remove()

                                            let alert = NSAlert()
                                            alert.alertStyle = .informational
                                            alert.messageText = String(localized: "Successfully removed Mythic Engine.")
                                            alert.informativeText = String(localized: "The latest version will be installed the next time you attempt to launch a Windows® game.")
                                            alert.addButton(withTitle: String(localized: "OK"))

                                            await alert.beginSheetModal(for: window)
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
                    }
                }
            }
        }

        // Version-specific app launch counter
        if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           var launchCountDictionary: [String: Int] = defaults.dictionary(forKey: "launchCount") as? [String: Int] {
            launchCountDictionary[shortVersion, default: 0] += 1
            defaults.set(launchCountDictionary, forKey: "launchCount")
        }

        // give people from <0.5.0 people a taste of vertical scroll library grid
        if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           shortVersion == "0.5.0",
           let launchCountDictionary = defaults.dictionary(forKey: "launchCount") as? [String: Int],
           defaults.bool(forKey: "isLibraryGridScrollingVertical") == false,
           launchCountDictionary[shortVersion] == 1 {
            // vertical as God intended
            defaults.set(true, forKey: "isLibraryGridScrollingVertical")
        }
    }

    func applicationDidBecomeActive(_: Notification) {
        _ = discordRPC.connect()
    }

    func applicationDidResignActive(_: Notification) {
        discordRPC.disconnect()
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if GameOperation.shared.current != nil || !GameOperation.shared.queue.isEmpty {
            let alert = NSAlert()
            alert.messageText = String(localized: "Are you sure you want to quit?")
            alert.informativeText = String(localized: "Mythic is still modifying games.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Quit"))
            alert.addButton(withTitle: String(localized: "Cancel"))

            if let window = sender.windows.first {
                alert.beginSheetModal(for: window) { response in
                    if case .alertFirstButtonReturn = response {
                        Task { @MainActor in
                            await Legendary.RunningCommands.shared.stopAll()
                            sender.reply(toApplicationShouldTerminate: true)
                        }
                    } else {
                        sender.reply(toApplicationShouldTerminate: false)
                    }
                }
            }

            return .terminateLater
        }

        return .terminateNow
    }

    @MainActor
    func applicationWillTerminate(_: Notification) {
        if defaults.bool(forKey: "quitOnAppClose") { try? Wine.killAll() }
        Task { await Legendary.RunningCommands.shared.stopAll() }
        Task { try? await Legendary.execute(arguments: ["cleanup"]) }
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
