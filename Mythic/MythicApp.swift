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
    @State private var isFirstLaunch: Bool
    @State private var isOnboardingPresented: Bool = false
    @State private var isInstallViewPresented: Bool = false
    @State private var isUpdatePromptPresented: Bool = false
    
    private let updaterController: SPUStandardUpdaterController
    
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
        
        Settings {
            UpdaterSettingsView(updater: updaterController.updater)
        }
    }
}
