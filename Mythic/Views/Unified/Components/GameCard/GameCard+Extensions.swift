//
//  GameCard+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/20/24.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

// TODO: architectural refactor, for new GameOperationManager
// swiftlint:disable nesting
extension GameCard {
    struct Buttons {
        struct Prominent {
            struct PlayButton: View {
                @Binding var game: Game
                var withLabel: Bool = false

                @Bindable private var operationManager: GameOperationManager = .shared

                @State private var isLaunchErrorAlertPresented = false
                @State private var launchError: Error?

                @State private var isEngineInstallationViewPresented: Bool = false
                @State private var engineInstallationError: Error?
                @State private var engineInstallationSuccess: Bool = false

                var body: some View {
                    Button {
                        Task(priority: .userInitiated) {
                            do {
                                try await game.launch()
                            } catch {
                                launchError = error
                                isLaunchErrorAlertPresented = true
                            }
                        }
                    } label: {
                        Group {
                            if withLabel {
                                Label("Play", systemImage: "play")
                            } else {
                                Label("Play", systemImage: "play")
                                    .labelStyle(.iconOnly)
                                    .padding(2)
                            }
                        }
                        .symbolVariant(.fill)
                        .customTransform { view in
                            if #unavailable(macOS 26.0) {
                                view.foregroundStyle(.black)
                            } else {
                                view
                            }
                        }
                    }
                    .disabled(operationManager.queue.contains(where: { $0.game == game && $0.type.modifiesFiles }))
                    // FIXME: .disabled(game.checkIfGameIsRunning())
                    .help("Play \"\(game.title)\"")
                    .accessibilityLabel("Play \"\(game.title)\"")

                    .background(.white)
                    .foregroundStyle(.black)

                    .alert(isPresented: $isLaunchErrorAlertPresented) {
                        if launchError is Engine.NotInstalledError {
                            return Alert(
                                title: Text("Mythic Engine is not installed."),
                                message: Text("""
                                    Mythic Engine is required to launch this game.
                                    Would you like to install it now?
                                    """),
                                primaryButton: .default(.init("Install")) {
                                    isEngineInstallationViewPresented = true
                                },
                                secondaryButton: .cancel()
                            )
                        } else {
                            return Alert(
                                title: Text("Error launching \"\(game.title)\"."),
                                message: Text(launchError?.localizedDescription ?? "Unknown Error.")
                            )
                        }
                    }
                    .sheet(isPresented: $isEngineInstallationViewPresented) {
                        EngineInstallationView(
                            isPresented: $isEngineInstallationViewPresented,
                            installationError: $engineInstallationError,
                            installationComplete: $engineInstallationSuccess
                        )
                        .padding()
                    }
                }
            }

            struct InstallButton: View {
                @Binding var game: Game
                var withLabel: Bool = false

                @EnvironmentObject var networkMonitor: NetworkMonitor
                @Bindable private var operationManager: GameOperationManager = .shared

                @State private var isInstallSheetPresented = false
                @State private var installError: Error?
                @State private var isInstallErrorAlertPresented = false
                @State private var isSteamClientSelectionPresented = false
                @State private var hasNativeSteam = false
                @State private var steamContainers: [URL] = []

                var body: some View {
                    Button {
                        if game is SteamGame {
                            hasNativeSteam = SteamClient.isNativeClientInstalled
                            steamContainers = SteamClient.installLocations.compactMap(\.containerURL)
                            if hasNativeSteam || !steamContainers.isEmpty {
                                isSteamClientSelectionPresented = true
                            } else {
                                installError = SteamClient.ClientNotInstalledError()
                                isInstallErrorAlertPresented = true
                            }
                        } else {
                            isInstallSheetPresented = true
                        }
                    } label: {
                        if withLabel {
                            Label("Install", systemImage: "arrow.down.to.line")
                        } else {
                            Label("Install", systemImage: "arrow.down.to.line")
                                .labelStyle(.iconOnly)
                                .padding(2)
                        }
                    }
                    .disabled(game.storefront != .steam && networkMonitor.epicAccessibilityState != .accessible)
                    .disabled(game.storefront == .local)
                    .disabled(operationManager.queue.contains(where: { $0.game == game && $0.type == .install }))
                    .help("Install \(game.description)")
                    .accessibilityLabel("Install \(game.description)")

                    .confirmationDialog("Choose a Steam client",
                                        isPresented: $isSteamClientSelectionPresented) {
                        if let steamGame = game as? SteamGame {
                            if hasNativeSteam {
                                Button("macOS Steam") {
                                    installSteamGame(steamGame, platform: .macOS)
                                }
                            }
                            ForEach(steamContainers, id: \.self) { containerURL in
                                Button("Windows Steam — \(containerURL.prettyPath)") {
                                    installSteamGame(steamGame, platform: .windows, containerURL: containerURL)
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Choose where to install \(game.title). Steam will handle the installation.")
                    }
                    .alert("Unable to install \"\(game.title)\".",
                           isPresented: $isInstallErrorAlertPresented,
                           presenting: installError) { _ in
                        if #available(macOS 26.0, *) {
                            Button(role: .close, action: {})
                        } else {
                            Button("OK", role: .cancel, action: {})
                        }
                    } message: { error in
                        Text(error.localizedDescription)
                    }
                    .sheet(isPresented: $isInstallSheetPresented) {
                        switch game {
                        case let epicGame as EpicGamesGame:
                            EpicGamesGameInstallationView(
                                game: .init(get: { epicGame },
                                            set: { game = $0 }),
                                isPresented: $isInstallSheetPresented
                            )
                            .padding()
                            .frame(width: 700, height: 380)
                        default: EmptyView()
                        }
                    }
                }

                private func installSteamGame(_ steamGame: SteamGame, platform: Game.Platform, containerURL: URL? = nil) {
                    Task {
                        do {
                            _ = try await SteamGameManager.install(
                                game: steamGame,
                                platform: platform,
                                containerURL: containerURL,
                                qualityOfService: .userInitiated
                            )
                        } catch {
                            installError = error
                            isInstallErrorAlertPresented = true
                        }
                    }
                }
            }
        }

        struct VerificationButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @EnvironmentObject var networkMonitor: NetworkMonitor
            @Bindable private var operationManager: GameOperationManager = .shared

            @State private var verificationError: Error?
            @State private var isVerificationErrorAlertPresented: Bool = false

            var body: some View {
                Button {
                    Task { [game] in
                        do {
                            try await game.verifyInstallation()
                        } catch {
                            verificationError = error
                            isVerificationErrorAlertPresented = true
                        }
                    }
                } label: {
                    if withLabel {
                        Label("Verify", systemImage: "checkmark.circle.badge.questionmark")
                    } else {
                        Label("Verify", systemImage: "checkmark.circle.badge.questionmark")
                            .labelStyle(.iconOnly)
                            .padding(2)
                    }
                }
                .disabled(game.storefront != .steam && networkMonitor.epicAccessibilityState != .accessible)
                .disabled(game.storefront == .local)
                .disabled(operationManager.queue.contains(where: { $0.game == game && $0.type == .repair }))
                .alert("Unable to verify installation.",
                       isPresented: $isVerificationErrorAlertPresented,
                       presenting: verificationError) { _ in
                    if #available(macOS 26.0, *) {
                        Button(role: .close, action: {})
                    } else {
                        Button("OK", role: .cancel, action: {})
                    }
                } message: { error in
                    Text(error?.localizedDescription ?? "Unknown error.")
                }
                .help("Verify game files' integrity for \(game.description).")
            }
        }
        struct UpdateButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @EnvironmentObject var networkMonitor: NetworkMonitor
            @Bindable private var operationManager: GameOperationManager = .shared
            
            var body: some View {
                Button {
                    Task(priority: .userInitiated) {
                        try await game.update()
                    }
                } label: {
                    if withLabel {
                        if let isUpdateAvailable = game.isUpdateAvailable {
                            Label(isUpdateAvailable ? "Update" : "Up to date",
                                  systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        } else {
                            Label("Update checking unavailable",
                                  systemImage: "checkmark.circle.dotted")
                        }
                    } else {
                        Label("Update", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                            .labelStyle(.iconOnly)
                            .padding(2)
                    }
                }
                .disabled(game.storefront != .steam && networkMonitor.epicAccessibilityState != .accessible)
                // FIXME: .disabled(game.checkIfGameIsRunning())
                .disabled(game.isUpdateAvailable != true)
                .disabled(operationManager.queue.contains(where: { $0.game == game && $0.type == .update }))
                .help("Update \"\(game.title)\"")
            }
        }

        struct SettingsButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @Binding var isGameSettingsSheetPresented: Bool

            var body: some View {
                Button {
                    isGameSettingsSheetPresented = true
                } label: {
                    if withLabel {
                        Label("Settings...", systemImage: "gear")
                    } else {
                        Label("Settings...", systemImage: "gear")
                            .labelStyle(.iconOnly)
                            .padding(2)
                    }
                }
                .help("Modify settings for \"\(game.title)\"")
                // FIXME: unable to propagate in menuview - this view is not in the hierarchy if called by `Menu`.
                // FIXME: you must add the sheet below to whatever view you call this button in!!
                /*
                 .sheet(isPresented: $isGameSettingsSheetPresented) {
                 GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
                 .padding()
                 .frame(minWidth: 750)
                 }
                 */
            }
        }

        struct FavouriteButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @State private var hoveringOverFavouriteButton = false
            @State private var animateFavouriteIcon = false

            var body: some View {
                Button {
                    game.isFavourited.toggle()
                    withAnimation { animateFavouriteIcon = game.isFavourited }
                } label: {
                    if withLabel {
                        Label(game.isFavourited ? "Remove from Favourites" : "Add to Favourites", systemImage: "star")
                            .symbolVariant(animateFavouriteIcon ? (hoveringOverFavouriteButton ? .slash.fill : .fill) : .none)
                            .contentTransition(.symbolEffect(.replace))
                    } else {
                        Label(game.isFavourited ? "Remove from Favourites" : "Add to Favourites", systemImage: "star")
                            .labelStyle(.iconOnly)
                            .symbolVariant(animateFavouriteIcon ? (hoveringOverFavouriteButton ? .slash.fill : .fill) : .none)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(2)
                    }
                }
                .onHover { hoveringOverFavouriteButton = $0 }
                .help(game.isFavourited
                      ? Text("Remove \"\(game.title)\" from favourites")
                      : Text("Favourite \"\(game.title)\""))
                .task { animateFavouriteIcon = game.isFavourited }
                .shadow(color: .secondary, radius: animateFavouriteIcon ? 20 : 0)
            }
        }

        struct DeleteButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @Binding var isUninstallSheetPresented: Bool

            @Bindable private var operationManager: GameOperationManager = .shared

            @State private var hoveringOverDestructiveButton = false

            var body: some View {
                // the uninstallation sheet this presents doubles as the confirmation step for this destructive action.
                Button(role: .destructive) {
                    isUninstallSheetPresented = true
                } label: {
                    if withLabel {
                        Label("Uninstall...", systemImage: "trash")
                    } else {
                        Label("Uninstall...", systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .padding(2)
                    }
                }
                .disabled(operationManager.queue.contains(where: { $0.game == game && $0.type == .uninstall }))
                // FIXME: .disabled(game.checkIfGameIsRunning())
                .help("Uninstall \"\(game.title)\"")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        hoveringOverDestructiveButton = hovering
                    }
                }
                // FIXME: unable to propagate in menuview - this view is not in the hierarchy if called by `Menu` smh so much for modularity.
                // FIXME: you must add the sheet below to whatever view you call this button in!!
                /*
                 .sheet(isPresented: $isUninstallSheetPresented) {
                 UninstallGameView(game: $game, isPresented: $isUninstallSheetPresented)
                 }
                 */
            }
        }
    }

    struct MenuView: View {
        @Binding var game: Game
        @State private var isGameSettingsSheetPresented: Bool = false
        @State private var isUninstallSheetPresented: Bool = false

        var body: some View {
            Group { // annoying, but the only way two sheets'll fit in here
                Menu {
                    GameCard.Buttons.SettingsButton(game: $game, withLabel: true, isGameSettingsSheetPresented: $isGameSettingsSheetPresented)
                    GameCard.Buttons.UpdateButton(game: $game, withLabel: true)
                    GameCard.Buttons.FavouriteButton(game: $game, withLabel: true)
                    GameCard.Buttons.DeleteButton(game: $game, withLabel: true, isUninstallSheetPresented: $isUninstallSheetPresented)
                } label: {
                    Button { } label: {
                        Label("More", systemImage: "ellipsis")
                            .labelStyle(.iconOnly)
                    }
                }
                .help("More actions")
                .accessibilityLabel("More actions for \"\(game.title)\"")
                .sheet(isPresented: $isGameSettingsSheetPresented) {
                    GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
                        .frame(width: 700, height: 520)
                }
                .customTransform { view in
                    if #unavailable(macOS 26.0) {
                        view
                            .fixedSize()
                    } else {
                        view
                    }
                }
            }
            .sheet(isPresented: $isUninstallSheetPresented) {
                switch game {
                case let epicGame as EpicGamesGame:
                    EpicGamesGameUninstallationView(game: .init(get: { epicGame }, set: { game = $0 }),
                                                    isPresented: $isUninstallSheetPresented)
                    .padding()
                    .frame(width: 700, height: 380)
                case let localGame as LocalGame:
                    LocalGameUninstallationView(game: .init(get: { localGame }, set: { game = $0 }),
                                                isPresented: $isUninstallSheetPresented)
                    .padding()
                    .frame(width: 700, height: 380)
                case let steamGame as SteamGame:
                    SteamGameUninstallationView(
                        game: .init(get: { steamGame }, set: { game = $0 }),
                        isPresented: $isUninstallSheetPresented
                    )
                    .padding()
                    .frame(width: 700, height: 380)
                default: EmptyView()
                }
            }
        }
    }

    struct ButtonsView: View {
        @Binding var game: Game
        var withLabel = false

        @Bindable private var operationManager: GameOperationManager = .shared
        @EnvironmentObject var networkMonitor: NetworkMonitor

        var body: some View {
            if let operation = operationManager.queue.first(where: { $0.isExecuting && $0.game == game }) {
                OperationCard.StatusView(operation: .constant(operation), withLabel: withLabel)
            } else if case .installed = game.installationState {
                Buttons.Prominent.PlayButton(game: $game, withLabel: withLabel)
                MenuView(game: $game)
                    .layoutPriority(1)
            } else {
                Buttons.Prominent.InstallButton(game: $game, withLabel: withLabel)
            }
        }
    }

    struct SubscriptedInfoView: View {
        @Binding var game: Game
        @Bindable var gameDataStore: GameDataStore = .shared

        var body: some View {
            SubscriptedTextView(game.storefront?.description ?? "Unknown")

            if GameDataStore.shared.recent == game {
                SubscriptedTextView("Recent")
            }
        }
    }

    struct TitleAndInformationView: View {
        @Binding var game: Game
        var font: Font = .title
        var withSubscriptedInfo: Bool = true

        var body: some View {
            HStack {
                Text(game.title)
                    .font(font)
                    .bold()
                    .truncationMode(.tail)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .help(game.title) // long titles may still truncate; keep the full title reachable

                if game.isFavourited {
                    Image(systemName: "star.fill")
                        .accessibilityLabel("Favourite")
                }
            }

            if withSubscriptedInfo {
                HStack {
                    GameCard.SubscriptedInfoView(game: $game)
                        .lineLimit(1)
                }
            }

#if DEBUG
                                Text("(\(game.id))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
#endif // DEBUG
        }
    }
}
// swiftlint:enable nesting

#Preview {
    LibraryView()
        .environmentObject(NetworkMonitor.shared)
}
