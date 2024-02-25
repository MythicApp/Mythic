//
//  AppDelegate.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 25/2/2024.
//

import SwiftUI
import Sparkle
import UserNotifications
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var updaterController: SPUStandardUpdaterController?
    var networkMonitor: NetworkMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if defaults.bool(forKey: "quitOnAppClose") { _ = Wine.killAll() }
    }
}
