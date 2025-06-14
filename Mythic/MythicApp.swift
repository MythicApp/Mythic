//
//  MythicApp.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 9/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Sparkle
import WhatsNewKit

@main
struct MythicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isOnboardingPresented") var isOnboardingPresented: Bool = true

    @StateObject private var networkMonitor: NetworkMonitor = .shared

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Mythic", id: "main") {
            Group {
                if isOnboardingPresented {
                    OnboardingView()
                        .task(priority: .high) {
                            await MainActor.run {
                                NSApp.mainWindow?.isImmersive = true
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(networkMonitor)
                        .task(priority: .high) {
                            await MainActor.run {
                                NSApp.mainWindow?.isImmersive = false
                            }
                        }
                }
            }
            .modifier(SparkleUpdaterSheetViewModifier())
            .frame(minWidth: 850, minHeight: 400)
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
            CommandGroup(replacing: .appInfo) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About Mythic")
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: {
                    SparkleUpdateControllerModel.shared.checkForUpdates(userInitiated: true)
                })

                Button("Restart Onboarding...") {
                    withAnimation {
                        isOnboardingPresented = true
                        }
                    }
                    .disabled(isOnboardingPresented)
                }
            
            CommandGroup(replacing: .help){
                Button("Mythic Documentation") {
                    if let docUrl = URL(string: "https://docs.getmythic.app/") {
                        NSWorkspace.shared.open(docUrl)
                        }
                    }
                Button("Discord Server") {
                    if let discordInviteUrl = URL(string: "https://discord.com/invite/58NZ7fFqPy") {
                        NSWorkspace.shared.open(discordInviteUrl)
                        }
                    }
                Button("GitHub Repository") {
                    if let githubUrl = URL(string: "https://github.com/MythicApp/Mythic") {
                        NSWorkspace.shared.open(githubUrl)
                    }
                }
                Divider()
                Button("What's new in Mythic") {
                    if let whatsNewUrl = URL(string: "https://github.com/MythicApp/Mythic/releases") {
                        NSWorkspace.shared.open(whatsNewUrl)
                    }
                }
                Divider()
                Button("Please consider donating!") {
                    if let donationUrl = URL(string: "https://ko-fi.com/vapidinfinity") {
                        NSWorkspace.shared.open(donationUrl)
                    }
                }
            }
                
            CommandGroup(replacing: .help){
                Button("Mythic Website") {
                    if let websiteURL = URL(string: "https://getmythic.app/") {
                        NSWorkspace.shared.open(websiteURL)
                        }
                    }

                Button("Mythic Documentation") {
                    if let docUrl = URL(string: "https://docs.getmythic.app/") {
                        NSWorkspace.shared.open(docUrl)
                        }
                    }
                Button("Discord Server") {
                    if let discordInviteUrl = URL(string: "https://discord.gg/kQKdvjTVqh") {
                        NSWorkspace.shared.open(discordInviteUrl)
                        }
                    }
                Button("GitHub Repository") {
                    if let githubUrl = URL(string: "https://github.com/MythicApp/Mythic") {
                        NSWorkspace.shared.open(githubUrl)
                    }
                }
                Button("Game Compatibility List") {
                    if let gameListURL = URL(string: "https://docs.google.com/spreadsheets/d/1W_1UexC1VOcbP2CHhoZBR5-8koH-ZPxJBDWntwH-tsc/") {
                        NSWorkspace.shared.open(gameListURL)
                    }
                }
                Divider()
                Button("What's new in Mythic") {
                    if let whatsNewUrl = URL(string: "https://github.com/MythicApp/Mythic/releases") {
                        NSWorkspace.shared.open(whatsNewUrl)
                    }
                }
                Divider()
                Button("Please consider donating!") {
                    if let donationUrl = URL(string: "https://ko-fi.com/vapidinfinity") {
                        NSWorkspace.shared.open(donationUrl)
                    }
                }
            }
        }

        Window("About Mythic", id: "about") {
            AboutView()
                .onAppear {
                    if let window = NSApp.window(withID: "about") {
                        window.isImmersive = true
                    }
                }
        }


        Settings {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NetworkMonitor.shared)
}
