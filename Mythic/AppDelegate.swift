//
//  AppDelegate.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 25/2/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Sparkle
import SwordRPC
import UserNotifications
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate { // https://arc.net/l/quote/zyfjpzpn
    func applicationDidFinishLaunching(_: Notification) {
        setenv("CX_ROOT", Bundle.main.bundlePath, 1)
        
        // MARK: initialize default UserDefaults Values
        defaults.register(defaults: [
            "discordRPC": true,
            "engineAutomaticallyChecksForUpdates": true,
            "quitOnAppClose": false
        ])
        
        // MARK: Container cleanup in the event of external deletion
        Wine.containerURLs = Wine.containerURLs.filter { files.fileExists(atPath: $0.path(percentEncoded: false)) }
        
        // MARK: Refresh legendary metadata
        Task(priority: .utility) {
            try? await Legendary.command(arguments: ["status"], identifier: "refreshMetadata") { _ in }
        }
        
        // MARK: Autosync Epic savedata
        Task(priority: .utility) {
            try? await Legendary.command(arguments: ["sync-saves"], identifier: "sync-saves") { _ in }
        }
        
        // MARK: 0.1.x bottle migration
        if let data = defaults.data(forKey: "allBottles"),
           let decodedData = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]] {
            
            Logger.app.log("Older bottle format detected, commencing bottle management system migration")
            
            var iterations = 0
            var convertedBottles: [Wine.Container] = .init()
            
            for (name, bottle) in decodedData {
                guard let urlArray = bottle["url"] as? [String: String], // unable to cast directly to URL
                      let relativeURL = urlArray["relative"],
                      let url: URL = .init(string: relativeURL.removingPercentEncoding ?? relativeURL) else {
                    return
                }
                
                var settings = Wine.defaultContainerSettings
                guard let oldSettings = bottle["settings"] as? [String: Bool] else { Logger.file.warning("Unable to read old bottle settings; using default"); continue }
                settings.metalHUD = oldSettings["metalHUD"] ?? settings.metalHUD
                settings.msync = oldSettings["msync"] ?? settings.msync
                settings.retinaMode = oldSettings["retinaMode"] ?? settings.retinaMode
                
                Task { @MainActor in
                    convertedBottles.append(.init(name: name, url: url, settings: settings))
                    Wine.containerURLs.insert(url)
                }
                
                iterations += 1
                
                Logger.app.log("converted \(url.prettyPath()) (\(iterations)/\(decodedData.count))")
            }
            
            Logger.file.notice("Bottle management system migration complete.")
            defaults.removeObject(forKey: "allBottles")
        }
        
        // MARK: >= 0.3.2 Bottle → Container migration
        let oldBottles = Bundle.appContainer!.appending(path: "Bottles")
        let newBottles = Bundle.appContainer!.appending(path: "Containers")
        if files.fileExists(atPath: oldBottles.path(percentEncoded: false)) {
            Logger.app.log("Commencing bottle renaming (Bottle → Container)")
            
            do {
                try files.moveItem(at: oldBottles, to: newBottles)
            } catch {
                Logger.app.error("Unable to rename default 'Bottles' folder to 'Containers': \(error.localizedDescription)")
            }
            
            if let bottleURLs = try? defaults.decodeAndGet([URL].self, forKey: "bottleURLs") {
                do {
                    try defaults.encodeAndSet(bottleURLs, forKey: "containerURLs")
                    defaults.removeObject(forKey: "bottleURLs")
                } catch {
                    Logger.app.error("Unable to re-encode default 'bottleURLs' as 'containerURLs': \(error.localizedDescription)")
                }
            }
            
            // Game-specific bottleURL migration
            for (key, value) in defaults.dictionaryRepresentation() where key.hasSuffix("_bottleURL") {
                guard let currentURL = value as? URL else { return }
                let currentPath = currentURL.path(percentEncoded: false)
                guard files.fileExists(atPath: currentPath) else { continue } // next loop

                let filteredURL: URL
                if currentPath.contains(oldBottles.path(percentEncoded: false)) {
                    let newPath = currentPath.replacingOccurrences(of: oldBottles.path(percentEncoded: false), with: newBottles.path(percentEncoded: false))
                    filteredURL = .init(fileURLWithPath: newPath)
                } else {
                    filteredURL = currentURL
                }
                
                defaults.set(filteredURL, forKey: key.replacingOccurrences(of: "_bottleURL", with: "_containerURL"))
                defaults.removeObject(forKey: key)
            }
            
            Logger.app.notice("Bottle renaming complete.")
        }
        
        // MARK: DiscordRPC Connection and Delegation Setting
        discordRPC.delegate = self
        if defaults.bool(forKey: "discordRPC") { _ = discordRPC.connect() }
        
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
#endif
        
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
        
        if defaults.bool(forKey: "engineAutomaticallyChecksForUpdates"), Engine.needsUpdate() == true, Engine.isLatestVersionReadyForDownload() == true {
            let alert = NSAlert()
            if let currentEngineVersion = Engine.version,
               let latestEngineVersion = Engine.fetchLatestVersion() {
                alert.messageText = "Update available. (\(currentEngineVersion) → \(latestEngineVersion))"
            } else {
                alert.messageText = "Update available."
            }
            
            alert.informativeText = "A new version of Mythic Engine has released. You're currently using \(Engine.version?.description ?? "an unknown version")."
            alert.addButton(withTitle: "Update")
            alert.addButton(withTitle: "Cancel")
            
            alert.showsHelp = true
            
            if let window = NSApp.windows.first { // no alternative ATM, swift compiler is clueless.
                alert.beginSheetModal(for: window) { response in
                    if case .alertFirstButtonReturn = response {
                        let confirmation = NSAlert()
                        confirmation.messageText = "Are you sure you want to update now?"
                        confirmation.informativeText = "Updating will remove the current version of Mythic Engine before installing the new one."
                        confirmation.addButton(withTitle: "Update")
                        confirmation.addButton(withTitle: "Cancel")
                        
                        confirmation.beginSheetModal(for: window) { response in
                            if case .alertFirstButtonReturn = response {
                                do {
                                    try Engine.remove()
                                    let app = MythicApp() // FIXME: is this dangerous or just stupid
                                    app.onboardingPhase = .engineDisclaimer
                                    app.isOnboardingPresented = true
                                } catch {
                                    let error = NSAlert()
                                    error.alertStyle = .critical
                                    error.messageText = "Unable to remove Mythic Engine."
                                    error.addButton(withTitle: "Quit")
                                    
                                    error.beginSheetModal(for: window) { response in
                                        if case .OK = response {
                                            exit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        /*
         MARK: Defaults version
         Useful for migration after non-backwards-compatible update
         */
        defaults.register(defaults: ["defaultsVersion": 1])
    }
    
    func applicationDidBecomeActive(_: Notification) {
        _ = discordRPC.connect()
    }
    
    func applicationDidResignActive(_: Notification) {
        discordRPC.disconnect()
    }
    
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
                    if response == .alertFirstButtonReturn {
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
        Legendary.stopAllCommands(forced: true)
        
        Task { try? await Legendary.command(arguments: ["cleanup"], identifier: "cleanup") { _ in } }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
}

extension AppDelegate: SPUUpdaterDelegate {
    
}

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
