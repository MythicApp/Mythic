//
//  Settings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/9/2023.
//

// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct SettingsView: View {
    @State private var isWineSectionExpanded: Bool = true
    @State private var isEpicSectionExpanded: Bool = true
    @State private var isMythicSectionExpanded: Bool = true
    @State private var isDefaultBottleSectionExpanded: Bool = true
    
    @AppStorage("minimiseOnGameLaunch") private var minimize: Bool = false
    @AppStorage("installBaseURL") private var installBaseURL: URL = Bundle.appGames!
    @AppStorage("quitOnAppClose") private var quitOnClose: Bool = false
    @AppStorage("discordRPC") private var rpc: Bool = true
    
    @State private var isForceQuitSuccessful: Bool?
    @State private var isShaderCachePurgeSuccessful: Bool?
    @State private var isEngineRemovalSuccessful: Bool?
    @State private var isCleanupSuccessful: Bool?
    
    @State private var isEngineRemovalAlertPresented: Bool = false
    
    var body: some View {
        Form {
            Section("Mythic", isExpanded: $isMythicSectionExpanded) {
                Toggle("Display Mythic activity status on Discord", isOn: $rpc)
                    .onChange(of: rpc) { _, newValue in
                        if newValue {
                            _ = discordRPC.connect()
                        } else {
                            discordRPC.disconnect()
                        }
                    }
                
                Toggle("Minimise to menu bar on game launch", isOn: $minimize)
                
                Toggle("Force quit all games when Mythic closes", isOn: $quitOnClose)
                
                HStack {
                    VStack {
                        HStack {
                            Text("Choose the default base path for games:")
                            Spacer()
                        }
                        HStack {
                            Text(installBaseURL.prettyPath())
                                .foregroundStyle(.placeholder)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !FileLocations.isWritableFolder(url: installBaseURL) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .help("Folder is not writable.")
                    }
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button("Browse...") { // TODO: replace with .fileImporter
                                let openPanel = NSOpenPanel()
                                openPanel.canChooseDirectories = true
                                openPanel.canChooseFiles = false
                                openPanel.canCreateDirectories = true
                                openPanel.allowsMultipleSelection = false
                                
                                if openPanel.runModal() == .OK {
                                    installBaseURL = openPanel.urls.first!
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        HStack {
                            Spacer()
                            Button("Reset to Default") {
                                installBaseURL = Bundle.appGames!
                            }
                        }
                    }
                }
                
                Button {
                    // TODO: mythic's folder in Libary/Preferences
                    // TODO: beat up legendary
                } label: {
                    Label("Reset Mythic", systemImage: "power.dotted")
                }
                .disabled(true)
                .help("Not implemented yet")
                
                Button {
                    // TODO: mythic's folder in Libary/Preferences
                } label: {
                    Label("Reset settings to default", systemImage: "clock.arrow.circlepath")
                }
                .disabled(true)
                .help("Not implemented yet")
                
            }
            
            Section("Wine/Mythic Engine", isExpanded: $isWineSectionExpanded) {
                HStack {
                    Button {
                        isForceQuitSuccessful = Wine.killAll()
                    } label: {
                        Label("Force Quit All Windows® Applications", systemImage: "xmark.app")
                    }
                    
                    if isForceQuitSuccessful != nil {
                        Image(systemName: isForceQuitSuccessful! ? "checkmark" : "xmark")
                    }
                }
                
                HStack {
                    Button {
                        isShaderCachePurgeSuccessful = Wine.purgeShaderCache()
                    } label: {
                        Label("Purge Shader Cache", systemImage: "square.stack.3d.up.slash.fill")
                    }
                    
                    if isShaderCachePurgeSuccessful != nil {
                        Image(systemName: isShaderCachePurgeSuccessful! ? "checkmark" : "xmark")
                    }
                }
                
                HStack {
                    Button {
                        isEngineRemovalAlertPresented = true
                    } label: {
                        Label("Remove Mythic Engine", systemImage: "gear.badge.xmark")
                    }
                    .alert(isPresented: $isEngineRemovalAlertPresented) {
                        Alert(
                            title: .init("Are you sure you want to remove Mythic Engine?"),
                            message: .init("It'll have to be reinstalled in order to play Windows® games."),
                            primaryButton: .destructive(.init("Remove")) {
                                do {
                                    try Libraries.remove()
                                    isEngineRemovalSuccessful = true
                                } catch {
                                    isEngineRemovalSuccessful = false
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    }
                    
                    if isEngineRemovalSuccessful != nil {
                        Image(systemName: isEngineRemovalSuccessful! ? "checkmark" : "xmark")
                    }
                }
            }
            .disabled(!Libraries.isInstalled())
            .help(Libraries.isInstalled() ? "Mythic Engine is not installed." : .init())
            
            Section("Epic", isExpanded: $isEpicSectionExpanded) {
                HStack {
                    Button {
                        Task {
                            try? await Legendary.command(arguments: ["cleanu["], identifier: "cleanup") { output, _ in
                                isCleanupSuccessful = output.stderr.contains("Cleanup complete") // [cli] INFO: Cleanup complete! Removed 0.00 MiB.
                            }
                        }
                    } label: {
                        Label("Clean Up Miscallaneous Caches", systemImage: "bubbles.and.sparkles")
                    }
                    
                    if isCleanupSuccessful != nil {
                        Image(systemName: isCleanupSuccessful! ? "checkmark" : "xmark")
                    }
                }
            }
            
            Section("Default Bottle Settings", isExpanded: $isDefaultBottleSectionExpanded) { // TODO: to replace with Wine.defaultBottleSettings
                BottleSettingsView(selectedBottle: .constant("Default"), withPicker: false)
            }
        }
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Tweaking some settings"
                presence.state = "Configuring Mythic"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
