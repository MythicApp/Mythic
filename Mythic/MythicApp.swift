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
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    
    private let updaterController: SPUStandardUpdaterController
    @State private var isOnboardingPresented = false
    
    init() {
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
                    if isFirstLaunch && !Legendary.signedIn() {
                        isOnboardingPresented = true
                    }
                }
                .sheet(isPresented: $isOnboardingPresented) {
                    OnboardingView(isPresented: $isOnboardingPresented, isFirstLaunch: $isFirstLaunch)
                        .fixedSize()
                        .interactiveDismissDisabled()
                }
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
