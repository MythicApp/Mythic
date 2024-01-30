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
import UserNotifications // TODO: TODO

// MARK: - Where it all begins!
@main
struct MythicApp: App {
    // MARK: - State Properties
    @AppStorage("isFirstLaunch") private var isFirstLaunch: Bool = true
    @State private var isOnboardingPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUpdatePromptPresented: Bool = false
    @State private var isNotificationPermissionsGranted = false
    
    // MARK: - Updater Controller
    private let updaterController: SPUStandardUpdaterController
    
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
            MainView()
                .frame(minWidth: 750, minHeight: 390)
                .task(priority: .high) {
                    if isFirstLaunch {
                        isOnboardingPresented = true
                        isFirstLaunch = false
                    } else if !Libraries.isInstalled() {
                        isInstallViewPresented = true
                    }
                    
                    if let latestVersion = Libraries.fetchLatestVersion(),
                       let currentVersion = Libraries.getVersion(),
                       latestVersion > currentVersion {
                        isUpdatePromptPresented = true
                    }
                }
                .task(priority: .background) {
                    if Libraries.isInstalled() {
                        await Wine.boot(name: "Default") { _ in }
                    }
                }
            
            // MARK: - Other Properties
            
                .sheet(isPresented: $isOnboardingPresented) {
                    OnboardingView(
                        isPresented: $isOnboardingPresented,
                        isInstallViewPresented: $isInstallViewPresented
                    )
                    .fixedSize()
                }
            
                .sheet(isPresented: $isInstallViewPresented) {
                    OnboardingView.InstallView(isPresented: $isInstallViewPresented)
                }
            
                .alert(isPresented: $isUpdatePromptPresented) {
                    Alert(
                        title: Text("Time for an update!"),
                        message: Text("The backend that allows you to play Windows® games on macOS just got an update."),
                        primaryButton: .default(Text("Update")),
                        secondaryButton: .cancel(Text("Later"))
                    )
                }
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: updaterController.updater.checkForUpdates)
                    .disabled(!updaterController.updater.canCheckForUpdates)
                
                Button("Restart Onboarding...") {
                    isOnboardingPresented = true
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
}
