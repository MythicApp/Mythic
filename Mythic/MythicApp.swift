//
//  MythicApp.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Sparkle

// MARK: - Where it all begins!
@main
struct MythicApp: App {
    // MARK: - App Delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - State Properties
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true // TODO: FIXME: RENAME BEFORE LAUNCH!
    @State var onboardingChapter: OnboardingEvo.Chapter = .allCases.first!
    @StateObject var networkMonitor = NetworkMonitor()
    @State private var showNetworkAlert = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isAlertPresented: Bool = false
    @State private var isNotificationPermissionsGranted = false
    @State private var bootError: Error?
    
    @State private var activeAlert: ActiveAlert = .updatePrompt
    enum ActiveAlert {
        case updatePrompt, bootError, offlineAlert
    }
    
    // MARK: - Updater Controller
    let updaterController: SPUStandardUpdaterController
    
    // MARK: - Initialization
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    // MARK: - App Body
    var body: some Scene {
        Window("Mythic", id: "main") {
            if isFirstLaunch {
                OnboardingEvo(fromChapter: onboardingChapter)
                    .transition(.opacity)
                    .frame(minWidth: 750, minHeight: 390)
                    .task(priority: .high) {
                        toggleTitleBar(false)
                        
                        if let window = NSApp.windows.first {
                            window.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
            } else {
                MainView()
                    .transition(.opacity)
                    .environmentObject(networkMonitor)
                    .frame(minWidth: 750, minHeight: 390)
                    .task(priority: .high) { toggleTitleBar(true) }
                    .task(priority: .medium) {
                        if let latestVersion = Libraries.fetchLatestVersion(),
                           let currentVersion = Libraries.getVersion(),
                           latestVersion > currentVersion {
                            activeAlert = .updatePrompt
                            isAlertPresented = true // TODO: add to onboarding chapter
                        }
                    }
                    .task(priority: .background) {
                        if Libraries.isInstalled(), Wine.allBottles?["Default"] == nil {
                            onboardingChapter = .defaultBottleSetup
                            isFirstLaunch = true
                        }
                    }
                
                // MARK: - Other Properties
                
                    .sheet(isPresented: $isInstallViewPresented) {
                        OnboardingView.InstallView(isPresented: $isInstallViewPresented)
                    }
                
                // Reference: https://arc.net/l/quote/cflghpbh
                    .onChange(of: networkMonitor.isEpicAccessible) { _, newValue in
                        if newValue == false {
                            /*
                            activeAlert = .offlineAlert
                            isAlertPresented = true
                             */
                        }
                    }
                
                    .alert(isPresented: $isAlertPresented) {
                        switch activeAlert {
                        case .updatePrompt:
                            Alert(
                                title: Text("Time for an update!"),
                                message: Text("The backend that allows you to play Windows® games on macOS just got an update."),
                                primaryButton: .default(Text("Update")), // TODO: download over previous engine
                                secondaryButton: .cancel(Text("Later"))
                            )
                        case .bootError: // TODO: replace with onboarding-style error
                            Alert(
                                title: Text("Unable to boot default bottle."),
                                message: Text("Mythic was unable to create the default Windows® container to launch Windows® games. Please contact support. (Error: \((bootError ?? UnknownError()).localizedDescription))"),
                                dismissButton: .destructive(Text("Quit Mythic")) { NSApp.terminate(nil) }
                            )
                        case .offlineAlert:
                            Alert(
                                title: Text("Can't connect."),
                                message: Text("Mythic is unable to connect to the internet. App functionality will be limited.")
                            )
                        }
                    }
            }
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: updaterController.updater.checkForUpdates)
                    .disabled(!updaterController.updater.canCheckForUpdates)
                
                if !isFirstLaunch {
                    Button("Restart Onboarding...") {
                        withAnimation(.easeInOut(duration: 2)) {
                            isFirstLaunch = true
                        }
                    }
                }
            }
        }
        
        // MARK: - Settings View
        Settings {
            UpdaterSettingsView(updater: updaterController.updater)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
}
