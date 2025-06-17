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

//    @EnvironmentObject var sparkleController: SparkleController

//    @AppStorage("gameCardSize") private var gameCardSize: Double = 250.0
//    @AppStorage("gameCardBlur") private var gameCardBlur: Double = 5.0
    @ObservedObject var appSettings = AppSettingsV1PersistentStateModel.shared

    @State private var isDefaultInstallLocationFileImporterPresented: Bool = false

    // Updated state variables for ActionButton
    @State private var isForceQuitting: Bool = false
    @State private var isForceQuitSuccessful: Bool?

    @State private var isShaderCachePurging: Bool = false
    @State private var isShaderCachePurgeSuccessful: Bool?

    @State private var isEngineRemoving: Bool = false
    @State private var isEngineRemovalSuccessful: Bool?

    @State private var isCleaning: Bool = false
    @State private var isCleanupSuccessful: Bool?

    @State private var isEpicCloudSynchronising: Bool = false
    @State private var isEpicCloudSyncSuccessful: Bool?

    @State private var isEngineStreamChangeAlertPresented: Bool = false
    @State private var isEngineRemovalAlertPresented: Bool = false
    @State private var isResetAlertPresented: Bool = false
    @State private var isResetSettingsAlertPresented: Bool = false

//    private var libraryViewSettingsSection: some View {
//        Section("Library", isExpanded: $isLibrarySettingsExpanded) {
//            Slider(value: $gameCardSize, in: 200...400, step: 25) {
//                Label("Gamecard Size", systemImage: "square.resize")
//                Text("Default is 3 ticks.")
//                    .foregroundStyle(.placeholder)
//            }
//
//            Slider(value: $gameCardBlur, in: 0...20, step: 5) {
//                Label("Gamecard Glow", systemImage: gameCardBlur <= 10 ? "sun.min" : "sun.max")
//            }
//
//            Picker("Scrolling Direction", systemImage: "arrow.up.and.down.and.sparkles", selection: $isLibraryGridScrollingVertical) {
//                Text("Vertical")
//                    .tag(true)
//                Text("Horizontal")
//                    .tag(false)
//            }
//        }
//    }

    private var launchingSettings: some View {
        Group {
            Toggle("Minimise to dock on game launch", systemImage: "dock.arrow.down.rectangle", isOn: $appSettings.store.hideOnGameLaunch)
            Toggle("Force quit all games when Mythic closes", systemImage: "xmark.app", isOn: $appSettings.store.closeGamesOnQuit)
        }
    }

    private var defaultInstallLocationPicker: some View {
        HStack {
            VStack(alignment: .leading) {
                Label("Default Install Location", systemImage: "externaldrive.fill.badge.checkmark")
                Text(appSettings.store.gameStorageDirectory.prettyPath())
                    .foregroundStyle(.placeholder)
            }

            Spacer()

            if !FileLocations.isWritableFolder(url: appSettings.store.gameStorageDirectory) {
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
                        appSettings.store.gameStorageDirectory = url
                    }
                }
                .buttonStyle(.borderedProminent)
                

                Button("Reset to Default") {
                    appSettings.store.gameStorageDirectory = Bundle.appGames!
                }
            }
        }
    }

    private var discordActivityStatusToggle: some View {
        Toggle("Display Mythic activity status on Discord", isOn: $appSettings.store.enableDiscordRichPresence)
            .onChange(of: appSettings.store.enableDiscordRichPresence) { _, newValue in
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
                try? await Legendary.command(arguments: ["cleanup"], identifier: "cleanup") { output in
                    withAnimation {
                        isCleanupSuccessful = output.stderr.contains("Cleanup complete")
                    }
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
                var syncSuccessful = false
                try? await Legendary.command(arguments: ["-y", "sync-saves"], identifier: "sync-saves") { output in
                    if (try? Regex(#"Got [0-9]+ remote save game"#).firstMatch(in: output.stderr)) != nil {
                        syncSuccessful = true
                    }
                }

                withAnimation {
                    isEpicCloudSyncSuccessful = syncSuccessful
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
                    do {
                        try Engine.remove()
                        isEngineRemovalSuccessful = true
                    } catch {
                        isEngineRemovalSuccessful = false
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
            Picker("Mythic update mode", systemImage: "arrow.down.app", selection: $appSettings.store.sparkleUpdateAction) {
                Text("Off")
                    .tag(AppSettingsV1PersistentStateModel.AutoUpdateAction.off)
                Text("Check")
                    .tag(AppSettingsV1PersistentStateModel.AutoUpdateAction.check)
                Text("Auto Install")
                    .tag(AppSettingsV1PersistentStateModel.AutoUpdateAction.install)
            }
        }
    }

    private var engineUpdateStreamPicker: some View {
        Picker("Stream", systemImage: "app.badge.clock", selection: $appSettings.store.engineReleaseBranch) {
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
        .onChange(of: appSettings.store.engineReleaseBranch) {
            isEngineStreamChangeAlertPresented = true
        }
        .alert(isPresented: $isEngineStreamChangeAlertPresented) {
            .init(
                title: .init("Would you like to reinstall Mythic Engine?"),
                message: .init("To change the engine type, Mythic Engine must be reinstalled through onboarding."),
                primaryButton: .destructive(.init("OK")) {
                    try? Engine.remove()

                    appSettings.store.inOnboarding = true
//                    let app = MythicApp() // FIXME: is this dangerous or just stupid
//                    app.onboardingPhase = .engineDisclaimer
//                    app.isOnboardingPresented = true
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var engineUpdateCheckerPicker: some View {
        Picker("Engine update mode", systemImage: "arrow.down.app.dashed", selection: $appSettings.store.engineUpdateAction) {
            Text("Off")
                .tag(AppSettingsV1PersistentStateModel.AutoUpdateAction.off)
            Text("Check")
                .tag(AppSettingsV1PersistentStateModel.AutoUpdateAction.check)
            Text("Auto Install")
                .tag(AppSettingsV1PersistentStateModel.AutoUpdateAction.install)
        }
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
                    appSettings.store = AppSettingsV1PersistentStateModel.defaultValue()
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
                    appSettings.store = AppSettingsV1PersistentStateModel.defaultValue()
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

//                    Tab("Views", systemImage: "document.viewfinder") {
//                        Form {
//                            libraryViewSettingsSection
//                        }
//                        .formStyle(.grouped)
//                    }

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
                        if Engine.exists {
                            Form {
                                engineKillRunningButton

                                engineRemovalButton

                                Section("Advanced", isExpanded: $isSettingsAdvancedSectionExpanded) {
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
                            VStack {
                                Text("Mythic Engine isn't installed.")
                                    .font(.bold(.title)())
                                Button {
                                    appSettings.store.inOnboarding = true
                                } label: {
                                    Label("Return to Onboarding & Install", systemImage: "arrow.down.to.line")
                                        .padding(5)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    Tab("Updates", systemImage: "arrow.down.app") {
                        Form {
                            Section("Mythic", isExpanded: $isUpdatesMythicSectionExpanded) {
                                mythicUpdateSettings
                            }

                            Section("Mythic Engine", isExpanded: $isUpdatesEngineSectionExpanded) {
                                engineUpdateStreamPicker

                                engineUpdateCheckerPicker
                            }
                        }
                        .formStyle(.grouped)
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

//                    libraryViewSettingsSection

                    Section("Updates", isExpanded: $isUpdateSettingsExpanded) {
                        mythicUpdateSettings

                        engineUpdateCheckerPicker
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

extension SettingsView {
    struct ActionButton: View {
        @Binding var operating: Bool
        @Binding var successful: Bool?
        let action: () async -> Void
        let label: () -> Label<Text, Image>
        let autoReset: Bool = true

        var body: some View {
            HStack {
                Button {
                    Task {
                        withAnimation {
                            operating = true
                            successful = nil
                        }

                        await action()

                        withAnimation {
                            operating = false
                        }
                    }
                } label: {
                    label()
                }
                .disabled(operating)

                if operating {
                    ProgressView()
                        .controlSize(.small)
                } else if let isSuccessful = successful {
                    Image(systemName: isSuccessful ? "checkmark" : "xmark")
                        .task {
                            if autoReset {
                                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3) {
                                    withAnimation {
                                        successful = nil
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SparkleController())
}
