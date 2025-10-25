//
//  SettingsView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC
import SemanticVersion

struct SettingsView: View {
    // Tab-style (macOS >14)
    @State private var isServicesDiscordSectionExpanded: Bool = true
    @State private var isServicesEpicSectionExpanded: Bool = true
    @State private var isSettingsAdvancedSectionExpanded: Bool = false
    @State private var isUpdatesMythicSectionExpanded: Bool = true
    @State private var isUpdatesEngineSectionExpanded: Bool = true

    // Legacy (macOS <14)
    @State private var isWineSectionExpanded: Bool = true
    @State private var isEpicSectionExpanded: Bool = true
    @State private var isMythicSectionExpanded: Bool = true
    @State private var isDefaultContainerSectionExpanded: Bool = true
    @State private var isLibrarySettingsExpanded: Bool = true
    @State private var isUpdateSettingsExpanded: Bool = true

    @EnvironmentObject var sparkleController: SparkleController

    @AppStorage("minimiseOnGameLaunch") private var minimize: Bool = false
    @AppStorage("installBaseURL") private var installBaseURL: URL = Bundle.appGames!
    @AppStorage("quitOnAppClose") private var quitOnClose: Bool = false
    @AppStorage("discordRPC") private var rpc: Bool = true
    @AppStorage("engineChannel") private var engineChannel: String = Engine.ReleaseChannel.stable.rawValue
    @AppStorage("engineAutomaticallyChecksForUpdates") private var engineAutomaticallyChecksForUpdates: Bool = true
    @AppStorage("isLibraryGridScrollingVertical") private var isLibraryGridScrollingVertical: Bool = true
    @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0
    @AppStorage("gameCardBlur") private var gameCardBlur: Double = 0.0

    @State private var isDefaultInstallLocationFileImporterPresented: Bool = false

    // Updated state variables for ActionButton
    @State private var isForceQuitting: Bool = false
    @State private var isForceQuitSuccessful: Bool?

    @State private var isShaderCachePurging: Bool = false
    @State private var isShaderCachePurgeSuccessful: Bool?

    @State private var isEngineRemoving: Bool = false
    @State private var isEngineRemovalSuccessful: Bool?

    @State private var isEngineInstallationViewPresented: Bool = false
    @State private var engineInstallationError: Error?
    @State private var engineInstallationSuccessful: Bool = false
    @State private var engineVersion: SemanticVersion?

    @State private var isCleaning: Bool = false
    @State private var isCleanupSuccessful: Bool?

    @State private var isEpicCloudSynchronising: Bool = false
    @State private var isEpicCloudSyncSuccessful: Bool?

    @State private var isEngineChannelChangeAlertPresented: Bool = false
    @State private var isEngineRemovalAlertPresented: Bool = false
    @State private var isResetAlertPresented: Bool = false
    @State private var isResetSettingsAlertPresented: Bool = false

    private var libraryViewSettingsSection: some View {
        Section("Library", isExpanded: $isLibrarySettingsExpanded) {
            Slider(value: $gameCardSize, in: 200...400, step: 25) {
                Label("Gamecard Size", systemImage: "square.resize")
                Text("Default is 1 tick.")
                    .foregroundStyle(.placeholder)
            }

            Slider(value: $gameCardBlur, in: 0...20, step: 5) {
                Label("Gamecard Glow", systemImage: gameCardBlur <= 10 ? "sun.min" : "sun.max")
            }

            Picker("Scrolling Direction", systemImage: "arrow.up.and.down.and.sparkles", selection: $isLibraryGridScrollingVertical) {
                Text("Vertical")
                    .tag(true)
                Text("Horizontal")
                    .tag(false)
            }
        }
    }

    private var launchingSettings: some View {
        Group {
            Toggle("Minimise to dock on game launch", systemImage: "dock.arrow.down.rectangle", isOn: $minimize)
            Toggle("Force quit all games when Mythic closes", systemImage: "xmark.app", isOn: $quitOnClose)
        }
    }

    private var defaultInstallLocationPicker: some View {
        HStack {
            VStack(alignment: .leading) {
                Label("Default Install Location", systemImage: "externaldrive.fill.badge.checkmark")
                Text(installBaseURL.prettyPath())
                    .foregroundStyle(.placeholder)
            }

            Spacer()

            if !FileLocations.isWritableFolder(url: installBaseURL) {
                Image(systemName: "exclamationmark.triangle")
                    .symbolVariant(.fill)
                    .help("Folder is not writable.")
            }

            VStack(alignment: .trailing) {
                Button("Browse...") {
                    isDefaultInstallLocationFileImporterPresented = true
                }
                .fileImporter(
                    isPresented: $isDefaultInstallLocationFileImporterPresented,
                    allowedContentTypes: [.folder]
                ) { result in
                    if case .success(let url) = result {
                        installBaseURL = url
                    }
                }
                .buttonStyle(.borderedProminent)
                

                Button("Reset to Default") {
                    installBaseURL = Bundle.appGames!
                }
            }
        }
    }

    private var discordActivityStatusToggle: some View {
        Toggle("Display Mythic activity status on Discord", isOn: $rpc)
            .onChange(of: rpc) { _, newValue in
                if newValue {
                    _ = discordRPC.connect()
                } else {
                    discordRPC.disconnect()
                }
            }
    }

    private var epicCleanupButton: some View {
        ActionButton(
            operating: $isCleaning,
            successful: $isCleanupSuccessful,
            action: {
                let commandResult = try? await Legendary.execute(arguments: ["cleanup"])
                withAnimation {
                    isCleanupSuccessful = commandResult?.standardError.contains("Cleanup complete")
                }
            },
            label: {
                Label("Clean Up Miscellaneous Caches", systemImage: "bubbles.and.sparkles")
            }
        )
    }

    private var epicCloudSyncButton: some View {
        ActionButton(
            operating: $isEpicCloudSynchronising,
            successful: $isEpicCloudSyncSuccessful,
            action: {
                let regex = try! Regex(#"Got [0-9]+ remote save game"#)
                let commandResult = try? await Legendary.execute(arguments: ["-y", "sync-saves"])
                withAnimation {
                    isEpicCloudSyncSuccessful = (try? regex.firstMatch(in: commandResult?.standardError ?? "") != nil)
                }
            },
            label: {
                Label("Manually Synchronise Cloud Saves", systemImage: "arrow.triangle.2.circlepath")
            }
        )
    }

    private var engineKillRunningButton: some View {
        ActionButton(
            operating: $isForceQuitting,
            successful: $isForceQuitSuccessful,
            action: {
                do {
                    try Wine.killAll()
                    isForceQuitSuccessful = true
                } catch {
                    isForceQuitSuccessful = false
                }
            },
            label: {
                Label("Force Quit Running Windows® Applications", systemImage: "xmark.app")
            }
        )
    }

    private var engineRemovalButton: some View {
        ActionButton(
            operating: $isEngineRemoving,
            successful: $isEngineRemovalSuccessful,
            action: {
                isEngineRemovalAlertPresented = true
            },
            label: {
                Label("Remove Mythic Engine", systemImage: "gear.badge.xmark")
            }
        )
        .alert(isPresented: $isEngineRemovalAlertPresented) {
            Alert(
                title: .init("Are you sure you want to remove Mythic Engine?"),
                message: .init("It'll have to be reinstalled in order to play Windows® games."),
                primaryButton: .destructive(.init("Remove")) {
                    Task { @MainActor in
                        do {
                            try await Engine.remove()
                            isEngineRemovalSuccessful = true
                        } catch {
                            isEngineRemovalSuccessful = false
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var enginePurgeShaderCacheButton: some View {
        ActionButton(
            operating: $isShaderCachePurging,
            successful: $isShaderCachePurgeSuccessful,
            action: {
                isShaderCachePurgeSuccessful = Wine.purgeShaderCache()
            },
            label: {
                Label("Purge D3DMetal Shader Cache", systemImage: "square.stack.3d.up.slash")
            }
        )
    }

    private var mythicUpdateSettings: some View {
        Group {
            Toggle(
                "Automatically check for Mythic updates",
                systemImage: "arrow.down.app.dashed",
                isOn: Binding(
                    get: { sparkleController.updater.automaticallyChecksForUpdates },
                    set: { sparkleController.updater.automaticallyChecksForUpdates = $0 }
                )
            )

            Toggle(
                "Automatically download Mythic updates",
                systemImage: "arrow.down.app",
                isOn: Binding(
                    get: { sparkleController.updater.automaticallyDownloadsUpdates },
                    set: { sparkleController.updater.automaticallyDownloadsUpdates = $0 }
                )
            )
        }
    }

    private var engineUpdateStreamPicker: some View {
        Picker("Release Channel", systemImage: "app.badge.clock", selection: $engineChannel) {
            Text("Stable")
                .tag(Engine.ReleaseChannel.stable.rawValue)
                .help("""
                    Existing stable features will be available in this channel.
                    This is the recommended stream for all users.
                    """)

            Text("Preview")
                .tag(Engine.ReleaseChannel.preview.rawValue)
                .help("""
                    Experimental new features may be available in this channel, at the cost of stability.
                    Use at your own risk.
                    """)
        }
        .onChange(of: engineChannel) {
            isEngineChannelChangeAlertPresented = true
        }
        .alert(isPresented: $isEngineChannelChangeAlertPresented) {
            .init(
                title: .init("Would you like to reinstall Mythic Engine?"),
                message: .init("To change the engine stream, Mythic Engine must be reinstalled through onboarding."),
                primaryButton: .destructive(.init("OK")) {
                    Task { @MainActor in
                        try? await Engine.remove()
                        isEngineInstallationViewPresented = true
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $isEngineInstallationViewPresented) {
            EngineInstallationView(
                isPresented: $isEngineInstallationViewPresented,
                installationError: $engineInstallationError,
                installationComplete: $engineInstallationSuccessful
            )
        }
    }

    private var engineUpdateCheckerToggle: some View {
        Toggle("Automatically check for Mythic Engine updates", systemImage: "arrow.down.app.dashed", isOn: $engineAutomaticallyChecksForUpdates)
    }

    private var fullAppResetButton: some View {
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
    }

    private var appResetButton: some View {
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
                },
                secondaryButton: .cancel()
            )
        }
    }

    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                TabView {
                    Tab("General", systemImage: "gear") {
                        Form {
                            fullAppResetButton

                            appResetButton
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Views", systemImage: "document.viewfinder") {
                        Form {
                            libraryViewSettingsSection
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Launching", systemImage: "play") {
                        Form {
                            launchingSettings
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Downloads", systemImage: "arrow.down.to.line") {
                        Form {
                            defaultInstallLocationPicker
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Updates", systemImage: "arrow.down.app") {
                        Form {
                            Section("Mythic", isExpanded: $isUpdatesMythicSectionExpanded) {
                                mythicUpdateSettings
                            }

                            Section("Mythic Engine", isExpanded: $isUpdatesEngineSectionExpanded) {
                                engineUpdateStreamPicker

                                engineUpdateCheckerToggle
                            }
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Services", systemImage: "app.connected.to.app.below.fill") {
                        Form {
                            Section("Discord", isExpanded: $isServicesDiscordSectionExpanded) {
                                discordActivityStatusToggle
                            }
                            .disabled(!discordRPC.isDiscordInstalled)
                            .help(discordRPC.isDiscordInstalled ? .init() : "Discord is not installed.")

                            Section("Epic Games", isExpanded: $isServicesEpicSectionExpanded) {
                                epicCleanupButton

                                epicCloudSyncButton

                                // TODO: potenially add manual cloud save deletion
                            }

                            Section("Steam", isExpanded: .constant(false)) { }
                                .help("Coming Soon")
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Engine", systemImage: "gamecontroller.circle") {
                        if Engine.isInstalled {
                            Form {
                                engineKillRunningButton

                                engineRemovalButton

                                Section("Advanced", isExpanded: $isSettingsAdvancedSectionExpanded) {
                                    enginePurgeShaderCacheButton
                                }
                            }
                            .formStyle(.grouped)
                            
                            
                            Text("\(engineVersion?.prettyString ?? "(Unknown Version)")")
                                .foregroundStyle(.placeholder)
                                .font(.footnote)
                                .padding()
                                .task {
                                    engineVersion = await Engine.installedVersion
                                }
                        } else {
                            Engine.NotInstalledView()
                                .padding()
                        }
                    }
                }
                // .tabViewStyle(.sidebarAdaptable) // FIXME: SwiftUI opens settings as a different type of window leading to this having displaced UI elements
            } else { //
                Form {
                    Section("Mythic", isExpanded: $isMythicSectionExpanded) {
                        discordActivityStatusToggle

                        launchingSettings

                        defaultInstallLocationPicker

                        fullAppResetButton

                        appResetButton
                    }

                    Section("Mythic Engine", isExpanded: $isWineSectionExpanded) {
                        engineUpdateStreamPicker

                        Group {
                            engineKillRunningButton

                            enginePurgeShaderCacheButton

                            engineRemovalButton

                            Text("\(engineVersion?.prettyString ?? "(Unknown Version)")")
                                .foregroundStyle(.placeholder)
                                .font(.footnote)
                                .padding()
                                .task {
                                    engineVersion = await Engine.installedVersion
                                }
                        }
                        .disabled(!Engine.isInstalled)
                        .help(Engine.isInstalled ? "Mythic Engine is not installed." : .init())
                    }

                    Section("Epic", isExpanded: $isEpicSectionExpanded) {
                        epicCleanupButton

                        epicCloudSyncButton

                        // TODO: potenially add manual cloud save deletion
                    }

                    libraryViewSettingsSection

                    Section("Updates", isExpanded: $isUpdateSettingsExpanded) {
                        mythicUpdateSettings

                        Toggle("Automatically check for Mythic Engine updates", isOn: $engineAutomaticallyChecksForUpdates)
                    }
                }
                .formStyle(.grouped)
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
    }
}

#Preview {
    SettingsView()
        .environmentObject(SparkleController())
}
