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
    @AppStorage("hasPresentedRPCBridgePrompt") var hasPresentedRPCBridgePrompt: Bool = false

    @State var onboardingPhase: OnboardingR2.Phase = .allCases.first!

    @State private var isDiscordRPCBridgeAlertPresented: Bool = false
    private var isDiscordInstalled: Bool {
        ["", "PTB", "Canary"].contains { isAppInstalled(bundleIdentifier: "com.hnc.Discord\($0)") }
    }
    var shouldIgnoreDiscordRPCPromptCheck: Bool {
        #if !DEBUG
        return !hasPresentedRPCBridgePrompt
        #else
        return true
        #endif
    }

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

    func installRPCBridge() {
        Task(priority: .userInitiated) {
            do {
                try await Engine.RPCBridge.modifyLaunchAgent(.install)
                let alert = NSAlert()
                alert.messageText = "Discord RPC Bridge installed successfully."
                alert.informativeText = """
                Supported Windows® games will now show their activity in Discord.
                You can disable this functionality at any time in Mythic Settings.
                """
                if let window = NSApp.windows.first {
                    await alert.beginSheetModal(for: window)
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.alertStyle = .critical
                errorAlert.messageText = "Unable to install Discord RPC Bridge."
                errorAlert.informativeText = """
                \(error.localizedDescription)
                Please try again in Mythic Settings.
                """
                errorAlert.addButton(withTitle: "OK")

                if let window = NSApp.windows.first {
                    await errorAlert.beginSheetModal(for: window)
                }
            }
        }
    }

    func presentRPCBridgeInstallationCancellationAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to cancel?"
        alert.informativeText = "You can enable Discord RPC Bridge later by going to Mythic's settings."

        let installButton = alert.addButton(withTitle: "Install")
        installButton.hasDestructiveAction = true

        alert.addButton(withTitle: "Cancel")

        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { response in
                if case .alertFirstButtonReturn = response {
                    installRPCBridge()
                }

                if case .OK = response {
                    #if !DEBUG
                    hasPresentedRPCBridgePrompt = true
                    #endif
                }
            }
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
                ContentView()
                    .transition(.opacity)
                    .environmentObject(networkMonitor)
                    .environmentObject(sparkleController)
                    .frame(minWidth: 750, minHeight: 390)
                    .onAppear {
                        toggleTitleBar(true)

                        if isDiscordInstalled,
                           !Engine.RPCBridge.launchAgentInstalled,
                           shouldIgnoreDiscordRPCPromptCheck {
                            isDiscordRPCBridgeAlertPresented = true
                        }
                    }
                    .alert(isPresented: $isDiscordRPCBridgeAlertPresented) {
                        .init(
                            title: .init("Install Discord RPC Bridge? (Beta)"),
                            message: .init("""
                            Mythic has detected that you have Discord installed.
                            Discord RPC Bridge is a beta feature that allows Windows® games to display their presence in Discord.
                            Would you like to install it?
                            """),
                            primaryButton: .default(.init("Install"), action: installRPCBridge),
                            secondaryButton: .cancel(.init("Cancel"), action: presentRPCBridgeInstallationCancellationAlert)
                        )
                    }
            }
        }

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
                whatsNewCollection: self)
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

extension MythicApp: WhatsNewCollectionProvider {
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "0.4.1",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(
                        systemName: "ladybug",
                        foregroundColor: .red
                    ),
                    title: "Bug Fixes & Performance Improvements",
                    subtitle: "Y'know, the usual."
                ),
                .init(
                    image: .init(
                        systemName: "checklist",
                        foregroundColor: .blue
                    ),
                    title: "Optional Pack support",
                    subtitle: "Epic Games that support selective downloads are now supported for download (e.g. Fortnite)."
                ),
                .init(
                    image: .init(
                        systemName: "cursorarrow.motionlines",
                        foregroundColor: .accent
                    ),
                    title: "More animations",
                    subtitle: "Added smooth animations and transitions."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/0.4.1"))
            )
        )
    }

}

#Preview {
    ContentView()
        .environmentObject(NetworkMonitor())
        .environmentObject(SparkleController())
}
