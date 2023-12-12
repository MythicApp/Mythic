//
//  MythicApp.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Sparkle

// MARK: - Where it all begins!
@main
struct MythicApp: App {
    // MARK: - State Properties
    @State private var isFirstLaunch: Bool
    @State private var isOnboardingPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUpdatePromptPresented: Bool = false
    
    // MARK: - Updater Controller
    private let updaterController: SPUStandardUpdaterController
    
    // MARK: - Initialization
    init() {
        self._isFirstLaunch = State(
            initialValue: UserDefaults.standard.bool(forKey: "isFirstLaunch")
        )
        
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
                .onAppear {
                    if isFirstLaunch || !Legendary.signedIn() {
                        isOnboardingPresented = true
                    } else if !Libraries.isInstalled() {
                        isInstallViewPresented = true
                    } else {
                        if let latestVersion = Libraries.fetchLatestVersion(),
                           let currentVersion = Libraries.getVersion(),
                           latestVersion > currentVersion {
                            isUpdatePromptPresented = true
                        }
                    }
                }
            
            // MARK: - Other Properties
            
                .sheet(isPresented: $isOnboardingPresented) {
                    OnboardingView(
                        isPresented: $isOnboardingPresented,
                        isFirstLaunch: $isFirstLaunch,
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
                        message: Text("The backend that allows you to play Windows games on macOS just got an update."),
                        primaryButton: .default(Text("Update")),
                        secondaryButton: .cancel(Text("Later"))
                    )
                }
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updaterController.updater.checkForUpdates)
                    .disabled(!updaterController.updater.canCheckForUpdates)
                
                Button("Restart Onboarding…") {
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
