//
//  Settings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/9/2023.
//

// Copyright © 2023 blackxfiied

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
    @State private var isDefaultContainerSectionExpanded: Bool = true
    @State private var isUpdateSettingsExpanded: Bool = true
    
    @EnvironmentObject var sparkle: SparkleController
    
    @ObservedObject private var mythicSettings = MythicSettings.shared
    
    @State private var isForceQuitSuccessful: Bool?
    @State private var isShaderCachePurgeSuccessful: Bool?
    @State private var isEngineRemovalSuccessful: Bool?
    @State private var isCleanupSuccessful: Bool?
    @State private var isEpicCloudSyncSuccessful: Bool?
    
    @State private var isEpicCloudSynchronising: Bool = false
    
    @State private var isEngineStreamChangeAlertPresented: Bool = false
    @State private var isEngineRemovalAlertPresented: Bool = false
    @State private var isResetAlertPresented: Bool = false
    @State private var isResetSettingsAlertPresented: Bool = false
    
    var body: some View {
        Form {
            Section("Mythic", isExpanded: $isMythicSectionExpanded) {
                Toggle("Display Mythic activity status on Discord", isOn: $mythicSettings.data.enableDiscordRPC)
                    .onChange(of: mythicSettings.data.enableDiscordRPC) { _, newValue in
                        if newValue {
                            _ = discordRPC.connect()
                        } else {
                            discordRPC.disconnect()
                        }
                    }
                
                Toggle("Minimise to menu bar on game launch", isOn: $mythicSettings.data.hideMythicOnGameLaunch)
                
                Toggle("Force quit all games when Mythic closes", isOn: $mythicSettings.data.closeGamesWithMythic)
                
                HStack {
                    VStack {
                        HStack {
                            Text("Choose the default base path for games:")
                            Spacer()
                        }
                        HStack {
                            Text(mythicSettings.data.gameInstallPath.prettyPath())
                                .foregroundStyle(.placeholder)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !FileLocations.isWritableFolder(url: mythicSettings.data.gameInstallPath) {
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
                                    mythicSettings.data.gameInstallPath = openPanel.urls.first!
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        HStack {
                            Spacer()
                            Button("Reset to Default") {
                                mythicSettings.data.gameInstallPath = Bundle.appGames!
                            }
                        }
                    }
                }
                
                Button {
                    isResetAlertPresented = true
                } label: {
                    Label("Reset Mythic", systemImage: "power.dotted")
                }
                .alert(isPresented: $isResetAlertPresented) {
                    .init(
                        title: .init("Reset Mythic?"),
                        message: .init("This will erase every persistent setting and container."),
                        primaryButton: .destructive(.init("Reset")) {
                            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                                defaults.removePersistentDomain(forName: bundleIdentifier)
                            }
                            
                            mythicSettings.data = .init()
                            
                            if let appHome = Bundle.appHome {
                                try? files.removeItem(at: appHome)
                            }
                            
                            if let containersDirectory = Wine.containersDirectory {
                                try? files.removeItem(at: containersDirectory)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                Button {
                    isResetSettingsAlertPresented = true
                } label: {
                    Label("Reset settings to default", systemImage: "clock.arrow.circlepath")
                }
                .alert(isPresented: $isResetSettingsAlertPresented) {
                    .init(
                        title: .init("Reset Mythic Settings?"),
                        message: .init("This will erase every persistent setting."),
                        primaryButton: .destructive(.init("Reset")) {
                            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                                defaults.removePersistentDomain(forName: bundleIdentifier)
                            }
                            
                            mythicSettings.data = .init()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
            }
            
            Section("Mythic Engine", isExpanded: $isWineSectionExpanded) {
                HStack {
                    Picker("Stream", selection: $mythicSettings.data.engineReleaseStream) {
                        Text("Stable", comment: "Within the context of Mythic Engine")
                            .tag(MythicSettings.EngineReleaseStream.stable)
                            .help("The stable stream of Mythic Engine.")
                        
                        Text("Preview", comment: "Within the context of Mythic Engine")
                            .tag(MythicSettings.EngineReleaseStream.staging)
                            .help("""
                            The experimental (staging) stream of Mythic Engine.
                            New features will be available here before being released onto the stable stream, but more issues may be present.
                            Use at your own risk.
                            """)
                    }
                    .onChange(of: mythicSettings.data.engineReleaseStream) {
                        isEngineStreamChangeAlertPresented = true
                    }
                    .alert(isPresented: $isEngineStreamChangeAlertPresented) {
                        .init(
                            title: .init("Would you like to reinstall Mythic Engine?"),
                            message: .init("To change the engine type, Mythic Engine must be reinstalled through onboarding."),
                            primaryButton: .destructive(.init("OK")) {
                                try? Engine.remove()
                                
                                mythicSettings.data.hasCompletedOnboarding = false
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                Group {
                    HStack {
                        Button {
                            withAnimation {
                                do {
                                    try Wine.killAll()
                                    isForceQuitSuccessful = true
                                } catch {
                                    isForceQuitSuccessful = false
                                }
                            }
                        } label: {
                            Label("Force Quit All Windows® Applications", systemImage: "xmark.app")
                        }
                        
                        if isForceQuitSuccessful != nil {
                            Image(systemName: isForceQuitSuccessful! ? "checkmark" : "xmark")
                        }
                    }
                    
                    HStack {
                        Button {
                            withAnimation {
                                isShaderCachePurgeSuccessful = Wine.purgeShaderCache()
                            }
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
                                    withAnimation {
                                        do {
                                            try Engine.remove()
                                            isEngineRemovalSuccessful = true
                                        } catch {
                                            isEngineRemovalSuccessful = false
                                        }
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                        
                        if isEngineRemovalSuccessful != nil {
                            Image(systemName: isEngineRemovalSuccessful! ? "checkmark" : "xmark")
                        }
                    }
                    
                    if Engine.exists {
                        Text("Version \(Engine.version?.description ?? "Unknown")")
                            .foregroundStyle(.placeholder)
                    }
                }
                .disabled(!Engine.exists)
                .help(Engine.exists ? "Mythic Engine is not installed." : .init())
            }
            
            Section("Epic", isExpanded: $isEpicSectionExpanded) {
                HStack {
                    Button {
                        Task {
                            try? await Legendary.command(arguments: ["cleanup"], identifier: "cleanup") { output in
                                withAnimation {
                                    isCleanupSuccessful = output.stderr.contains("Cleanup complete") // [cli] INFO: Cleanup complete! Removed 0.00 MiB.
                                }
                            }
                        }
                    } label: {
                        Label("Clean Up Miscallaneous Caches", systemImage: "bubbles.and.sparkles")
                    }
                    
                    if isCleanupSuccessful != nil {
                        Image(systemName: isCleanupSuccessful! ? "checkmark" : "xmark")
                    }
                }
                
                HStack {
                    Button {
                        Task {
                            withAnimation {
                                isEpicCloudSynchronising = true
                            }
                            
                            try? await Legendary.command(arguments: ["sync-saves"], identifier: "sync-saves") { output in // TODO: turn into Legendary function
                                if (try? Regex(#"Got [0-9]+ remote save game"#).firstMatch(in: output.stderr)) != nil {
                                    withAnimation {
                                        isEpicCloudSyncSuccessful = true
                                    }
                                }
                            }
                            
                            withAnimation {
                                isEpicCloudSyncSuccessful = (isEpicCloudSyncSuccessful == true)
                                isEpicCloudSynchronising = false
                            }
                        }
                    } label: {
                        Label("Manually Synchronise Cloud Saves", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    if isEpicCloudSynchronising {
                        ProgressView()
                            .controlSize(.small)
                    } else if isEpicCloudSyncSuccessful != nil {
                        Image(systemName: isEpicCloudSyncSuccessful! ? "checkmark" : "xmark")
                    }
                }
                
                // TODO: potenially add manual cloud save deletion
            }
            
            Section("Updates", isExpanded: $isUpdateSettingsExpanded) {
                Toggle("Automatically check for Mythic updates", isOn: Binding(
                    get: { sparkle.updater.automaticallyChecksForUpdates },
                    set: { sparkle.updater.automaticallyChecksForUpdates = $0 }
                ))
                
                Toggle("Automatically download Mythic updates", isOn: Binding(
                    get: { sparkle.updater.automaticallyDownloadsUpdates },
                    set: { sparkle.updater.automaticallyDownloadsUpdates = $0 }
                ))
                
                Toggle("Automatically check for Mythic Engine updates", isOn: $mythicSettings.data.engineUpdatesAutoCheck)
            }
            
            /* FIXME: TODO: Temporarily disabled; awaiting view that directly edits Wine.defaultContainerSettings.
             Section("Default Container Settings", isExpanded: $isDefaultContainerSectionExpanded) {
             // ContainerSettingsView something
             }
             */
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
        .environmentObject(SparkleController())
}
