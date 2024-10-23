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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - State Properties
    @ObservedObject private var mythicSettings = MythicSettings.shared
    @State var onboardingPhase: OnboardingR2.Phase = .allCases.first!
    
    @StateObject private var networkMonitor: NetworkMonitor = .init()
    @StateObject private var sparkleController: SparkleController = .init()
    
    @State private var bootError: Error?
    
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
            if !mythicSettings.data.hasCompletedOnboarding {
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
                MainView()
                    .transition(.opacity)
                    .environmentObject(networkMonitor)
                    .environmentObject(sparkleController)
                    .frame(minWidth: 750, minHeight: 390)
                    .onAppear { toggleTitleBar(true) }
            }
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: sparkleController.updater.checkForUpdates)
                    .disabled(!sparkleController.updater.canCheckForUpdates)
                
                Button("Restart Onboarding...") {
                    withAnimation(.easeInOut(duration: 2)) {
                        mythicSettings.data.hasCompletedOnboarding = false
                    }
                }
                .disabled(!mythicSettings.data.hasCompletedOnboarding)
                // .keyboardShortcut("O", modifiers: [.command])
            }
        }
        
        // MARK: - Settings View
        /*
        Settings {
            SettingsView()
        }
         */
    }
}

#Preview {
    MainView()
        .environmentObject(NetworkMonitor())
        .environmentObject(SparkleController())
}
