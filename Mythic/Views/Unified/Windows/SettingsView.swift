//
//  SettingsView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 25/10/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import SwordRPC
import SemanticVersion

struct SettingsView: View {
    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                TabView {
                    Tab("General", systemImage: "gear") {
                        Form {
                            GeneralView()
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Views", systemImage: "document.viewfinder") {
                        Form {
                            ViewSettingsView()
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Launching", systemImage: "play") {
                        Form {
                            LaunchingView()
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Downloads", systemImage: "arrow.down.to.line") {
                        Form {
                            OperationsView()
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Updates", systemImage: "arrow.down.app") {
                        Form {
                            UpdatesView()
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Services", systemImage: "app.connected.to.app.below.fill") {
                        Form {
                            ServicesView()
                        }
                        .formStyle(.grouped)
                    }

                    Tab("Engine", systemImage: "gamecontroller.circle") {
                        Form {
                            EngineView()
                        }
                        .formStyle(.grouped)
                    }
                }
                .tabViewStyle(.automatic)
            } else { // macOS 15 unavailable ↓
                Form {
                    Section("General", content: { GeneralView() })
                    Section("Views", content: { ViewSettingsView() })
                    Section("Launching", content: { LaunchingView() })
                    Section("Operations", content: { OperationsView() })
                    Section("Updates", content: { UpdatesView() })
                    Section("Services", content: { ServicesView() })
                    Section("Engine", content: { EngineView() })
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
    struct GeneralView: View {
        @State private var isResetAlertPresented = false
        @State private var isResetSettingsAlertPresented = false

        var body: some View {
            Button("Reset Mythic", systemImage: "power.dotted") {
                isResetAlertPresented = true
            }
            .alert(
                "Reset Mythic?",
                isPresented: $isResetAlertPresented,
                actions: {
                    Button("OK", role: .destructive) {
                        if let bundleIdentifier = Bundle.main.bundleIdentifier {
                            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
                        }

                        if let appHome = Bundle.appHome {
                            try? FileManager.default.removeItem(at: appHome)
                        }

                        if let containersDirectory = Wine.containersDirectory {
                            try? FileManager.default.removeItem(at: containersDirectory)
                        }
                    }

                    Button("Cancel", role: .cancel) {  }
                },
                message: {
                    Text("This will erase every persistent setting and container, and cannot be undone.")
                }
            )

            Button("Reset settings to default", systemImage: "clock.arrow.circlepath") {
                isResetSettingsAlertPresented = true
            }
            .alert(
                "Reset Mythic Settings?",
                isPresented: $isResetSettingsAlertPresented,
                actions: {
                    Button("OK", role: .destructive) {
                        if let bundleIdentifier = Bundle.main.bundleIdentifier {
                            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
                        }
                    }

                    Button("Cancel", role: .cancel) {  }
                },
                message: {
                    Text("This will erase every persistent setting.")
                }
            )
        }
    }

    struct ViewSettingsView: View {
        @AppStorage("gameCardSize") private var gameCardSize: Double = 200.0
        @AppStorage("gameImageCardBlur") private var imageCardBlur: Double = 0.0

        @AppStorage("isLibraryGridScrollingVertical") private var isLibraryGridScrollingVertical: Bool = true

        var body: some View {
            Slider(value: $gameCardSize, in: 200...400, step: 25) {
                Label("Gamecard Size", systemImage: "square.resize")
                Text("Default is 1 tick.")
                    .foregroundStyle(.secondary)
            }

            Slider(value: $imageCardBlur, in: 0...20, step: 5) {
                Label("Gamecard Glow", systemImage: imageCardBlur <= 10 ? "sun.min" : "sun.max")
            }

            Picker("Scrolling Direction", systemImage: "arrow.up.and.down.and.sparkles", selection: $isLibraryGridScrollingVertical) {
                Text("Vertical")
                    .tag(true)

                Text("Horizontal")
                    .tag(false)
            }
        }
    }

    struct LaunchingView: View {
        @AppStorage("minimiseOnGameLaunch") private var minimiseOnLaunch: Bool = false
        @AppStorage("quitOnAppClose") private var quitOnClose: Bool = false

        var body: some View {
            Toggle("Minimise to dock on game launch", systemImage: "dock.arrow.down.rectangle", isOn: $minimiseOnLaunch)
            Toggle("Force quit all games when Mythic closes", systemImage: "xmark.app", isOn: $quitOnClose)
        }
    }

    struct OperationsView: View {
        @AppStorage("installBaseURL") private var installBaseURL: URL = Bundle.appGames!
        @State private var isImporterPresented: Bool = false

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Label("Default Install Location", systemImage: "externaldrive.fill.badge.checkmark")
                    HStack {
                        Text(installBaseURL.prettyPath)
                            .foregroundStyle(.secondary)

                        if !FileLocations.isWritableFolder(url: installBaseURL) {
                            Image(systemName: "exclamationmark.triangle")
                                .symbolVariant(.fill)
                                .help("Folder is not writable.")
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Button("Browse...") {
                        isImporterPresented = true
                    }
                    .fileImporter(
                        isPresented: $isImporterPresented,
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
    }

    struct UpdatesView: View {
        @State private var isMythicUpdatesSectionExpanded: Bool = true
        @State private var isEngineUpdatesSectionExpanded: Bool = true

        @AppStorage("engineChannel") private var engineChannel: String = Engine.ReleaseChannel.stable.rawValue
        @State private var isEngineChannelChangeAlertPresented: Bool = false

        @State private var isEngineInstallationViewPresented: Bool = false
        @State private var engineInstallationError: Error?
        @State private var engineInstallationSuccessful: Bool = false

        @AppStorage("engineAutomaticallyChecksForUpdates") private var engineAutomaticallyChecksForUpdates: Bool = true

        var body: some View {
            Section("Mythic", isExpanded: $isMythicUpdatesSectionExpanded) {
//                Toggle(
//                    "Automatically check for Mythic updates",
//                    systemImage: "arrow.down.app.dashed",
//                    isOn: Binding(
//                        get: { sparkleController.updater.automaticallyChecksForUpdates },
//                        set: { sparkleController.updater.automaticallyChecksForUpdates = $0 }
//                    )
//                )
//
//                Toggle(
//                    "Automatically download Mythic updates",
//                    systemImage: "arrow.down.app",
//                    isOn: Binding(
//                        get: { sparkleController.updater.automaticallyDownloadsUpdates },
//                        set: { sparkleController.updater.automaticallyDownloadsUpdates = $0 }
//                    )
//                )
            }

            Section("Mythic Engine", isExpanded: $isEngineUpdatesSectionExpanded) {
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
                .alert(
                    "Would you like to reinstall Mythic Engine?",
                    isPresented: $isEngineChannelChangeAlertPresented,
                    actions: {
                        Button("OK", role: .destructive) {
                            Task { @MainActor in
                                try? await Engine.remove()
                                isEngineInstallationViewPresented = true
                            }
                        }

                        Button("Cancel", role: .cancel) {  }
                    },
                    message: {
                        Text("""
                        To change Mythic Engine's release channel, it must be reinstalled.
                        If you choose not to, Mythic Engine will attempt to update to a 
                        newer version if it exists the next time it launches.
                        """)
                    }
                )
                .sheet(isPresented: $isEngineInstallationViewPresented) {
                    EngineInstallationView(
                        isPresented: $isEngineInstallationViewPresented,
                        installationError: $engineInstallationError,
                        installationComplete: $engineInstallationSuccessful
                    )
                    .padding()
                }

                Toggle("Automatically check for Mythic Engine updates", systemImage: "arrow.down.app.dashed", isOn: $engineAutomaticallyChecksForUpdates)
            }
        }
    }

    struct ServicesView: View {
        @AppStorage("discordRPC") private var discordRPCEnabled: Bool = true
        @State private var isServicesDiscordSectionExpanded: Bool = true
        @State private var isServicesEpicSectionExpanded: Bool = true

        @State private var isCleaning: Bool = false
        @State private var isCleanupSuccessful: Bool?

        @State private var isEpicCloudSynchronising: Bool = false
        @State private var isEpicCloudSyncSuccessful: Bool?

        var body: some View {
            Section("Discord", isExpanded: $isServicesDiscordSectionExpanded) {
                Toggle("Display Mythic activity status on Discord", isOn: $discordRPCEnabled)
                    .onChange(of: discordRPCEnabled) { _, newValue in
                        if newValue {
                            _ = discordRPC.connect()
                        } else {
                            discordRPC.disconnect()
                        }
                    }
            }
            .disabled(!discordRPC.isDiscordInstalled)
            .help(discordRPC.isDiscordInstalled ? .init() : "Discord is not installed.")

            Section("Epic Games", isExpanded: $isServicesEpicSectionExpanded) {
                OperationButton(
                    "Clean Up Miscellaneous Caches",
                    systemImage: "bubbles.and.sparkles",
                    operating: $isCleaning,
                    successful: $isCleanupSuccessful
                ) {
                    let commandResult = try? await Legendary.execute(arguments: ["cleanup"])
                    isCleanupSuccessful = commandResult?.standardError.contains("Cleanup complete")
                }

                OperationButton(
                    "Manually Synchronise Cloud Saves",
                    systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
                    operating: $isEpicCloudSynchronising,
                    successful: $isEpicCloudSyncSuccessful
                ) {
                    let regex = try! Regex(#"Got [0-9]+ remote save game"#) // swiftlint:disable:this force_try
                    let commandResult = try? await Legendary.execute(arguments: ["-y", "sync-saves"])
                    isEpicCloudSyncSuccessful = (try? regex.firstMatch(in: commandResult?.standardError ?? "") != nil)
                }

                // TODO: potenially add manual cloud save deletion
            }

            Section("Steam", isExpanded: .constant(false)) { }
                .help("Coming Soon")
        }
    }

    struct EngineView: View {
        @State private var isForceQuitting: Bool = false
        @State private var isForceQuitSuccessful: Bool?

        @State private var isEngineRemoving: Bool = false
        @State private var isEngineRemovalSuccessful: Bool?

        @State private var isEngineRemovalAlertPresented: Bool = false

        @State private var isShaderCachePurging: Bool = false
        @State private var isShaderCachePurgeSuccessful: Bool?

        @State private var isAdvancedSectionExpanded: Bool = false

        @State private var engineVersion: SemanticVersion?
        var body: some View {
            if Engine.isInstalled {
                OperationButton(
                    "Force Quit Running Windows® Applications",
                    systemImage: "xmark.app",
                    operating: $isForceQuitting,
                    successful: $isForceQuitSuccessful
                ) {
                    do {
                        try Wine.killAll()
                        isForceQuitSuccessful = true
                    } catch {
                        isForceQuitSuccessful = false
                    }
                }

                OperationButton(
                    "Remove Mythic Engine",
                    systemImage: "gear.badge.xmark",
                    operating: $isEngineRemoving,
                    successful: $isEngineRemovalSuccessful
                ) {
                    isEngineRemovalAlertPresented = true
                }
                .alert(
                    "Are you sure you want to remove Mythic Engine?",
                    isPresented: $isEngineRemovalAlertPresented,
                    actions: {
                        Button("Remove", role: .destructive) {
                            Task { @MainActor in
                                do {
                                    try await Engine.remove()
                                    isEngineRemovalSuccessful = true
                                } catch {
                                    isEngineRemovalSuccessful = false
                                }
                            }
                        }

                        Button("Cancel", role: .cancel) {  }
                    },
                    message: {
                        Text("It'll have to be reinstalled in order to play Windows® games.")
                    }
                )

                Section("Advanced", isExpanded: $isAdvancedSectionExpanded) {
                    OperationButton(
                        "Purge D3DMetal Shader Cache",
                        systemImage: "square.stack.3d.up.slash",
                        operating: $isShaderCachePurging,
                        successful: $isShaderCachePurgeSuccessful
                    ) {
                        isShaderCachePurgeSuccessful = (try? Wine.purgeD3DMetalShaderCache()) != nil
                    }
                }

                Text("Mythic Engine \(engineVersion?.prettyString ?? "(Unknown Version)")")
                    .foregroundStyle(.secondary)
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
}

#Preview {
    SettingsView()
}
