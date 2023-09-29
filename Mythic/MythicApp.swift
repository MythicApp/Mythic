//
//  MythicApp.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/9/2023.
//

import SwiftUI
import Sparkle

@main
struct MythicApp: App {
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 750, minHeight: 390)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updaterController.updater.checkForUpdates)
                    .disabled(!updaterController.updater.canCheckForUpdates)
            }
        }
        
        Settings {
            UpdaterSettingsView(updater: updaterController.updater)
        }
    }
}
