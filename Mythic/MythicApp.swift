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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - State Properties
    @AppStorage("isOnboardingPresented") var isOnboardingPresented: Bool = true
    @State var onboardingPhase: OnboardingR2.Phase = .allCases.first!
    @StateObject var networkMonitor: NetworkMonitor = .init()
    
    @State private var bootError: Error?
    
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    
    // MARK: - Updater Controller
    private let updaterController: SPUStandardUpdaterController
    
    // MARK: - Initialization
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        _automaticallyChecksForUpdates = State(initialValue: updaterController.updater.automaticallyChecksForUpdates)
        _automaticallyDownloadsUpdates = State(initialValue: updaterController.updater.automaticallyDownloadsUpdates)
    }
    
    func toggleTitleBar(_ value: Bool) {
        if let window = NSApp.windows.first {
            window.titlebarAppearsTransparent = !value
            window.isMovableByWindowBackground = !value
            window.titleVisibility = value ? .visible : .hidden
            window.standardWindowButton(.miniaturizeButton)?.isHidden = !value
            window.standardWindowButton(.zoomButton)?.isHidden = !value
        }
    }
    
    // MARK: - App Body
    var body: some Scene {
        Window("Mythic", id: "main") {
            if isOnboardingPresented {
                OnboardingR2(fromPhase: onboardingPhase)
                    .onAppear {
                        toggleTitleBar(false)
                        
                        // Bring to front
                        if let window = NSApp.mainWindow {
                            window.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
            } else {
                MainView(
                    automaticallyChecksForUpdates: $automaticallyChecksForUpdates,
                    automaticallyDownloadsUpdates: $automaticallyDownloadsUpdates
                )
                .transition(.opacity)
                .environmentObject(networkMonitor)
                .frame(minWidth: 750, minHeight: 390)
                .onAppear { toggleTitleBar(true) }
            }
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: updaterController.updater.checkForUpdates)
                    .disabled(!updaterController.updater.canCheckForUpdates)
                
                if !isOnboardingPresented {
                    Button("Restart Onboarding...") {
                        withAnimation(.easeInOut(duration: 2)) {
                            isOnboardingPresented = true
                        }
                    }
                }
            }
        }
        
        // MARK: - Settings View
        Settings {
            SettingsView(
                automaticallyChecksForUpdates: $automaticallyChecksForUpdates,
                automaticallyDownloadsUpdates: $automaticallyDownloadsUpdates
            )
        }
    }
}

#Preview {
    MainView(
        automaticallyChecksForUpdates: .constant(true),
        automaticallyDownloadsUpdates: .constant(false)
    )
        .environmentObject(NetworkMonitor())
}
