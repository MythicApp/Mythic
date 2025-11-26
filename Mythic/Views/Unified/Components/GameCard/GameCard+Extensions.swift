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
                        if let operation = operationManager.queue.first,
                           operation.game == game,
                           case .launch = operation.type {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.black)

                                if withLabel {
                                    Text("Launching")
                                }
                            }
                        } else {
                            Group {
                                if withLabel {
                                    Label("Play", systemImage: "play")
                                } else {
                                    Image(systemName: "play")
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
                    }
                    .disabled(operationManager.queue.first?.game == game)
                    // FIXME: .disabled(game.checkIfGameIsRunning())
                    .help("Play \"\(game.title)\"")

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

                var body: some View {
                    Button {
                        isInstallSheetPresented = true
                    } label: {
                        if withLabel {
                            Label("Install", systemImage: "arrow.down.to.line")
                        } else {
                            Image(systemName: "arrow.down.to.line")
                                .padding(2)
                        }
                    }
                    .disabled(networkMonitor.epicAccessibilityState != .accessible)
                    .disabled(operationManager.queue.first?.game == game)
                    .disabled(game.storefront == .local)
                    .help("Install \(game.description)")

                    .sheet(isPresented: $isInstallSheetPresented) {
                        InstallGameView(game: $game, isPresented: $isInstallSheetPresented)
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
                    Task {
                        do {
                            try await Task { @MainActor [game] in
                                try await game.verifyInstallation()
                            }.value
                        } catch {
                            verificationError = error
                            isVerificationErrorAlertPresented = true
                        }
                    }
                } label: {
                    if withLabel {
                        Label("Verify", systemImage: "checkmark.circle.badge.questionmark")
                    } else {
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .padding(2)
                    }
                }
                .disabled(networkMonitor.epicAccessibilityState != .accessible)
                .disabled(operationManager.queue.first?.game == game)
                .disabled(game.storefront == .local)
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
                                  systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Update checking unavailable",
                                  systemImage: "checkmark.circle.dotted")
                        }
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .padding(2)
                    }
                }
                .disabled(networkMonitor.epicAccessibilityState != .accessible)
                // FIXME: .disabled(game.checkIfGameIsRunning())
                .disabled(operationManager.queue.first?.game == game)
                .disabled(game.isUpdateAvailable != true)
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
                        Label("Settings", systemImage: "gear")
                    } else {
                        Image(systemName: "gear")
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
                        Label(game.isFavourited ? "Unfavourite" : "Favourite", systemImage: "star")
                            .symbolVariant(animateFavouriteIcon ? (hoveringOverFavouriteButton ? .slash.fill : .fill) : .none)
                            .contentTransition(.symbolEffect(.replace))
                    } else {
                        Image(systemName: "star")
                            .symbolVariant(animateFavouriteIcon ? (hoveringOverFavouriteButton ? .slash.fill : .fill) : .none)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(2)
                    }
                }
                .onHover { hoveringOverFavouriteButton = $0 }
                .help("Favourite \"\(game.title)\"")
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
                Button {
                    isUninstallSheetPresented = true
                } label: {
                    if withLabel {
                        Label("Delete", systemImage: "xmark.bin")
                    } else {
                        Image(systemName: "xmark.bin")
                            .padding(2)
                    }
                }
                .disabled(operationManager.queue.first?.game == game)
                // FIXME: .disabled(game.checkIfGameIsRunning())
                .help("Delete \"\(game.title)\"")
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
                        Image(systemName: "ellipsis")
                    }
                }
                .sheet(isPresented: $isGameSettingsSheetPresented) {
                    GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
                        .frame(width: 700, height: 380)
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
                UninstallGameView(game: $game,
                                  isPresented: $isUninstallSheetPresented)
            }
        }
    }

    struct ButtonsView: View {
        @Binding var game: Game
        var withLabel = false

        @Bindable private var operationManager: GameOperationManager = .shared
        @EnvironmentObject var networkMonitor: NetworkMonitor

        var body: some View {
            if operationManager.queue.first?.game == game {
                GameInstallProgressView(withPercentage: false)
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

        var body: some View {
            SubscriptedTextView(game.storefront?.description ?? "Unknown")

            if Game.store.recent == game {
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
                    .lineLimit(1)

                if game.isFavourited {
                    Image(systemName: "star.fill")
                }
            }

            if withSubscriptedInfo {
                HStack {
                    GameCard.SubscriptedInfoView(game: $game)
                        .lineLimit(1)
                }
            }
        }
    }
}
// swiftlint:enable nesting

#Preview {
    LibraryView()
        .environmentObject(NetworkMonitor.shared)
}
