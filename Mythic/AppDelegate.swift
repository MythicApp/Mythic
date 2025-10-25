//
//  AppDelegate.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/2/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import OSLog
import Sparkle
import SwiftUI
import SwordRPC
import UserNotifications

import Firebase
import FirebaseCore
import FirebaseCrashlytics

// TODO: modularise
class AppDelegate: NSObject, NSApplicationDelegate { // https://arc.net/l/quote/zyfjpzpn
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
            alert.messageText = "Move Mythic to the Applications folder?"
            alert.informativeText = "Mythic has detected it's running outside of the applications folder."
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Cancel")

            if let window = NSApp.windows.first, let optimalAppURL = optimalAppURL {
                alert.beginSheetModal(for: window) { response in
                    if case .alertFirstButtonReturn = response {
                        do {
                            _ = try files.replaceItemAt(optimalAppURL, withItemAt: currentAppURL)
                            workspace.open(optimalAppURL)
                        } catch {
                            Logger.file.error("Unable to move Mythic to Applications: \(error)")

                            let error = NSAlert()
                            error.messageText = "Unable to move Mythic to \"\(optimalAppURL.deletingLastPathComponent().prettyPath())\"."
                            error.addButton(withTitle: "Quit")

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

                let message = "Mythic Engine update available."
                if let currentEngineVersion = await Engine.installedVersion,
                   let latestRelease = try? await Engine.getLatestRelease() {
                    alert.messageText = "\(message) (\(currentEngineVersion) → \(latestRelease.version))"
                } else {
                    alert.messageText = message
                }

                alert.informativeText = """
                    A new version of Mythic Engine has released.
                    You're currently using \(await Engine.installedVersion?.description ?? "an unknown version").
                    """

                alert.addButton(withTitle: "Update")
                alert.addButton(withTitle: "Cancel")

                if let window = NSApp.windows.first {
                    alert.beginSheetModal(for: window) { response in
                        if case .alertFirstButtonReturn = response {
                            let confirmation = NSAlert()
                            confirmation.messageText = "Are you sure you want to update now?"

                            confirmation.informativeText = """
                                This will remove the current version of Mythic Engine.
                                The latest version will be installed the next time you attempt to launch a Windows® game.
                                """

                            confirmation.addButton(withTitle: "Update")
                            confirmation.addButton(withTitle: "Cancel")

                            confirmation.beginSheetModal(for: window) { response in
                                if case .alertFirstButtonReturn = response {
                                    Task(priority: .userInitiated) {
                                        do {
                                            try await Engine.remove()

                                            let alert = NSAlert()
                                            alert.alertStyle = .informational
                                            alert.messageText = "Successfully removed Mythic Engine."
                                            alert.informativeText = "The latest version will be installed the next time you attempt to launch a Windows® game."
                                            alert.addButton(withTitle: "OK")

                                            await alert.beginSheetModal(for: window)
                                        } catch {
                                            let errorAlert = NSAlert()
                                            errorAlert.alertStyle = .critical
                                            errorAlert.messageText = "Unable to remove Mythic Engine."
                                            errorAlert.informativeText = error.localizedDescription
                                            errorAlert.addButton(withTitle: "OK")

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
            alert.messageText = "Are you sure you want to quit?"
            alert.informativeText = "Mythic is still modifying games."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")

            if let window = sender.windows.first {
                alert.beginSheetModal(for: window) { response in
                    if case .alertFirstButtonReturn = response {
                        sender.reply(toApplicationShouldTerminate: true)
                    } else {
                        sender.reply(toApplicationShouldTerminate: false)
                    }
                }
            }
        }

        return .terminateNow
    }

    func applicationWillTerminate(_: Notification) {
        if defaults.bool(forKey: "quitOnAppClose") { try? Wine.killAll() }
        Task { await Legendary.RunningCommands.shared.stopAll() }
        Task { try? await Legendary.execute(arguments: ["cleanup"]) }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {}

extension AppDelegate: SPUUpdaterDelegate {} // FIXME: nonfunctional

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
