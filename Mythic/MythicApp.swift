//
//  MythicApp.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 9/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Sparkle
import WhatsNewKit

// MARK: - Where it all begins!
@main
struct MythicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - State Properties
    @AppStorage("isOnboardingPresented") var isOnboardingPresented: Bool = true
    @State var onboardingPhase: OnboardingR2.Phase = .allCases.first!
    
    @StateObject private var networkMonitor: NetworkMonitor = .shared
    @StateObject private var sparkleController: SparkleController = .init()
    
    @State private var bootError: Error?
    
    // MARK: - App Body
    var body: some Scene {
        Window("Mythic", id: "main") {
            if isOnboardingPresented {
                OnboardingR2(fromPhase: onboardingPhase)
                    .contentTransition(.opacity)
                    .onAppear {
                        if let window = NSApp.mainWindow {
                            window.isImmersive = true

                            window.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
            } else {
                ContentView()
                    .contentTransition(.opacity)
                    .environmentObject(networkMonitor)
                    .environmentObject(sparkleController)
                    .frame(minWidth: 750, minHeight: 390)
                    .onAppear {
                        if let window = NSApp.mainWindow {
                            window.isImmersive = false
                        }
                    }
            }
        }
        .handlesExternalEvents(matching: ["open"])
        .environment(
            \.whatsNew,
             WhatsNewEnvironment(
                versionStore:
                    {
#if DEBUG
                        InMemoryWhatsNewVersionStore()
#else
                        UserDefaultsWhatsNewVersionStore()
#endif
                    }(),
                whatsNewCollection: self
             )
        )
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: sparkleController.updater.checkForUpdates)
                    .disabled(!sparkleController.updater.canCheckForUpdates)
                
                Button("Restart Onboarding...") {
                    withAnimation(.easeInOut(duration: 2)) {
                        isOnboardingPresented = true
                    }
                }
                .disabled(isOnboardingPresented)
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
    ContentView()
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(SparkleController())
}
