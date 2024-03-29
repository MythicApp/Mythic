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
    var updaterController: SPUStandardUpdaterController?
    var networkMonitor: NetworkMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // MARK: initialize default UserDefaults Values
        UserDefaults.standard.register(
            defaults: [
                "discordRPC": true
            ]
        )
        
        // MARK: Bottle removal if folder was deleted externally
        if let bottles = Wine.allBottles {
            for (key, value) in bottles where !files.fileExists(atPath: value.url.path(percentEncoded: false)) {
                Wine.allBottles?.removeValue(forKey: key)
            }
        }
        
        if Libraries.isInstalled() {
            Wine.allBottles = Wine.allBottles // creates default bottle automatically due to custom getter
        }
        
        // MARK: Applications folder disclaimer
#if !DEBUG // TODO: possibly turn this into an onboarding-style message.
        let appURL = Bundle.main.bundleURL
        
        // MARK: Move to Applications
        if !appURL.pathComponents.contains("Applications") {
            let alert = NSAlert()
            alert.messageText = "Move Mythic to the Applications folder?"
            alert.informativeText = """
            Mythic has detected it's running outside of the applications folder.
            """
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn, let globalApps = FileLocations.globalApplications {
                do {
                    _ = try files.replaceItemAt(appURL, withItemAt: globalApps)
                    workspace.open(globalApps.appending(path: "Mythic.app")
                    )
                } catch {
                    Logger.file.error("Unable to move Mythic to Applications: \(error)")
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
        
        // MARK: DiscordRPC Connection and Delegation Setting
        discordRPC.delegate = self
        if defaults.bool(forKey: "discordRPC") { _ = discordRPC.connect() }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if defaults.bool(forKey: "quitOnAppClose") { Wine.killAll() }
        // TODO: stop download alert if downloading before closure
        Legendary.stopAllCommands()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
}

extension AppDelegate: SwordRPCDelegate {
    func swordRPCDidConnect(_ rpc: SwordRPC) {
        rpc.setPresence({
            var presence: RichPresence = .init()
            presence.details = "Just launched Mythic"
            presence.state = "Idle"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            
            return presence
        }())
    }
}
