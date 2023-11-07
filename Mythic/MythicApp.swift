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
    
    private let updaterController: SPUStandardUpdaterController
    @State private var isOnboardingPresented = false
    
    @State private var isInstallViewPresented: Bool = false
    
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
        WindowGroup {
            MainView()
                .frame(minWidth: 750, minHeight: 390)
                .onAppear {
                    if isFirstLaunch || !Legendary.signedIn() {
                        isOnboardingPresented = true
                    } else if !Libraries.isInstalled() {
                        isInstallViewPresented = true
                    }
                }
            
                .sheet(isPresented: $isOnboardingPresented) {
                    ///*
                    OnboardingView(
                        isPresented: $isOnboardingPresented,
                        isFirstLaunch: $isFirstLaunch,
                        isInstallViewPresented: $isInstallViewPresented
                    )
                        .fixedSize()
                     //*/
                    // OnboardingView.InstallView()
                }
            
                .sheet(isPresented: $isInstallViewPresented) {
                    OnboardingView.InstallView(isPresented: $isInstallViewPresented)
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
