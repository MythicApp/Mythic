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

struct SettingsView: View {
    // Tab-style (macOS >14)


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
    @AppStorage("engineBranch") private var engineBranch: String = Engine.Stream.stable.rawValue
    @AppStorage("engineAutomaticallyChecksForUpdates") private var engineAutomaticallyChecksForUpdates: Bool = true
    @AppStorage("isLibraryGridScrollingVertical") private var isLibraryGridScrollingVertical: Bool = false
    @AppStorage("gameCardSize") private var gameCardSize: Double = 250.0
    @AppStorage("gameCardBlur") private var gameCardBlur: Double = 10.0

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

    private var libraryViewSettingsSection: some View {
        Section("Library", isExpanded: $isLibrarySettingsExpanded) {
            Slider(value: $gameCardSize, in: 200...400, step: 25) {
                Label("Gamecard Size", systemImage: "square.resize")
                Text("Default is 3 ticks.")
                    .foregroundStyle(.placeholder)
            }

            Slider(value: $gameCardBlur, in: 0...20, step: 5) {
                Label("Gamecard Blur", systemImage: gameCardBlur >= 10 ? "sun.min" : "sun.max")
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
                Button("Browse...") { // TODO: replace with .fileImporter
                    let openPanel = NSOpenPanel()
                    openPanel.canChooseDirectories = true
                    openPanel.canChooseFiles = false
                    openPanel.canCreateDirectories = true
                    openPanel.allowsMultipleSelection = false

                    if case .OK = openPanel.runModal() {
                        installBaseURL = openPanel.urls.first!
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
    }

    private var epicCloudSyncButton: some View {
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
    }

    private var engineKillRunningButton: some View {
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
                Label("Force Quit Running Windows® Applications", systemImage: "xmark.app")
            }

            if isForceQuitSuccessful != nil {
                Image(systemName: isForceQuitSuccessful! ? "checkmark" : "xmark")
            }
        }
    }

    private var engineRemovalButton: some View {
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
    }

    private var enginePurgeShaderCacheButton: some View {
        HStack {
            Button {
                withAnimation {
                    isShaderCachePurgeSuccessful = Wine.purgeShaderCache()
                }
            } label: {
                Label("Purge D3DMetal Shader Cache", systemImage: "square.stack.3d.up.slash")
                    .symbolVariant(.slash.fill)
            }

            if isShaderCachePurgeSuccessful != nil {
                Image(systemName: isShaderCachePurgeSuccessful! ? "checkmark" : "xmark")
            }
        }
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
        Picker("Stream", systemImage: "app.badge.clock", selection: $engineBranch) {
            Text("Stable", comment: "Within the context of Mythic Engine")
                .tag(Engine.Stream.stable.rawValue)
                .help("""
                Existing stable features will be available in this stream.
                This is the recommended stream for all users.
                """)

            Text("Preview", comment: "Within the context of Mythic Engine")
                .tag(Engine.Stream.staging.rawValue)
                .help("""
                Experimental new features may be available in this stream, at the cost of stability.
                Use at your own risk.
                """)
        }
        .onChange(of: engineBranch) {
            isEngineStreamChangeAlertPresented = true
        }
        .alert(isPresented: $isEngineStreamChangeAlertPresented) {
            .init(
                title: .init("Would you like to reinstall Mythic Engine?"),
                message: .init("To change the engine type, Mythic Engine must be reinstalled through onboarding."),
                primaryButton: .destructive(.init("OK")) {
                    try? Engine.remove()

                    let app = MythicApp() // FIXME: is this dangerous or just stupid
                    app.onboardingPhase = .engineDisclaimer
                    app.isOnboardingPresented = true
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var engineUpdateCheckerToggle: some View {
        Toggle("Automatically check for Mythic Engine updates", systemImage: "arrow.down.app.dashed", isOn: $engineAutomaticallyChecksForUpdates)
    }

    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                TabView {
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

                    Tab("Services", systemImage: "app.connected.to.app.below.fill") {
                        Form {
                            Section("Discord", isExpanded: .constant(true)) {
                                discordActivityStatusToggle
                            }
                            .disabled(!discordRPC.isDiscordInstalled)
                            .help(discordRPC.isDiscordInstalled ? .init() : "Discord is not installed.")

                            Section("Epic Games", isExpanded: .constant(true)) {
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
                        if Engine.exists {
                            Form {
                                engineKillRunningButton

                                engineRemovalButton

                                Section("Advanced", isExpanded: .constant(true)) {
                                    enginePurgeShaderCacheButton
                                }
                            }
                            .formStyle(.grouped)

                            if Engine.exists {
                                Text("\(Engine.version?.prettyString ?? "(Unknown Version)")")
                                    .foregroundStyle(.placeholder)
                                    .font(.footnote)
                                    .padding()
                            }
                        } else {
                            // TODO: engine not exists
                        }
                    }

                    Tab("Updates", systemImage: "arrow.down.app") {
                        Form {
                            Section("Mythic", isExpanded: .constant(true)) {
                                mythicUpdateSettings
                            }

                            Section("Mythic Engine", isExpanded: .constant(true)) {
                                engineUpdateStreamPicker

                                engineUpdateCheckerToggle
                            }
                        }
                        .formStyle(.grouped)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else { //
                Form {
                    Section("Mythic", isExpanded: $isMythicSectionExpanded) {
                        discordActivityStatusToggle

                        launchingSettings

                        defaultInstallLocationPicker

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

                    Section("Mythic Engine", isExpanded: $isWineSectionExpanded) {
                        engineUpdateStreamPicker

                        Group {
                            engineKillRunningButton

                            enginePurgeShaderCacheButton

                            engineRemovalButton

                            if Engine.exists {
                                Text("Version \(Engine.version?.prettyString ?? "Unknown")")
                                    .foregroundStyle(.placeholder)
                            }
                        }
                        .disabled(!Engine.exists)
                        .help(Engine.exists ? "Mythic Engine is not installed." : .init())
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

                    /* FIXME: TODO: Temporarily disabled; awaiting view that directly edits Wine.defaultContainerSettings.
                     Section("Default Container Settings", isExpanded: $isDefaultContainerSectionExpanded) {
                     // ContainerSettingsView something
                     }
                     */
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
