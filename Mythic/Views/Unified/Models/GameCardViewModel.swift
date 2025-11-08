//
//  GameCardViewModel.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/20/24.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import SwiftyJSON
import Shimmer

// TODO: refactor to actually be a viewmodel, not a view extension
@Observable final class GameCardViewModel: ObservableObject {

    // swiftlint:disable nesting
    struct Buttons {
        struct Prominent {
            struct PlayButton: View {
                @Binding var game: Game
                var withLabel: Bool = false

                @ObservedObject private var operation: GameOperation = .shared

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
                        if game.isLaunching {
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
                    .disabled(game.isLaunching)
                    .disabled(operation.runningGameIDs.contains(game.id))
                    .disabled(operation.current?.game == game)
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
                @ObservedObject private var operation: GameOperation = .shared

                @State private var isInstallSheetPresented = false

                var body: some View {
                    if operation.current?.game == game {
                        GameInstallProgressView()
                    } else {
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
                        .disabled(networkMonitor.epicAccessibilityState != .accessible || operation.queue.contains(where: { $0.game == game }))
                        .help("Install \"\(game.title)\"")

                        .sheet(isPresented: $isInstallSheetPresented) {
                            InstallGameView(game: $game, isPresented: $isInstallSheetPresented)
                        }
                    }
                }
            }
        }

        struct VerificationButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @EnvironmentObject var networkMonitor: NetworkMonitor
            @ObservedObject private var operation: GameOperation = .shared

            var body: some View {
                Button {
                    operation.queue.append(
                        GameOperation.InstallArguments(
                            game: game,
                            platform: game.platform!,
                            type: .repair
                        )
                    )
                } label: {
                    if withLabel {
                        Label("Verify", systemImage: "checkmark.circle.badge.questionmark")
                    } else {
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .padding(2)
                    }
                }
                .disabled(networkMonitor.epicAccessibilityState != .accessible)
                .help("Game verification is required for \"\(game.title)\".")
            }
        }
        struct UpdateButton: View {
            @Binding var game: Game
            var withLabel: Bool = false

            @EnvironmentObject var networkMonitor: NetworkMonitor
            @ObservedObject private var operation: GameOperation = .shared

            var body: some View {
                Button {
                    operation.queue.append(
                        GameOperation.InstallArguments(
                            game: game,
                            platform: game.platform!,
                            type: .update
                        )
                    )
                } label: {
                    if withLabel {
                        if game.needsUpdate {
                            Label("Update", systemImage: "arrow.triangle.2.circlepath")
                        } else if game.source != .local {
                            Label("Up to date", systemImage: "checkmark")
                        } else {
                            Label("Update checking unsupported", systemImage: "checkmark.circle.dotted")
                        }
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .padding(2)
                    }
                }
                .disabled(networkMonitor.epicAccessibilityState != .accessible)
                .disabled(operation.runningGameIDs.contains(game.id))
                .disabled(!game.needsUpdate)
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
                // FIXME: unable to propagate in menuview - this view is not in the hierarchy if called by `Menu`. smh so much for modularity
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

            @ObservedObject private var operation: GameOperation = .shared

            @State private var hoveringOverDestructiveButton = false

            var isDeleteDisabled: Bool {
                operation.current?.game != nil || operation.runningGameIDs.contains(game.id)
            }

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
                .disabled(isDeleteDisabled)
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
                    GameCardViewModel.Buttons.SettingsButton(game: $game, withLabel: true, isGameSettingsSheetPresented: $isGameSettingsSheetPresented)
                    GameCardViewModel.Buttons.UpdateButton(game: $game, withLabel: true)
                    GameCardViewModel.Buttons.FavouriteButton(game: $game, withLabel: true)
                    GameCardViewModel.Buttons.DeleteButton(game: $game, withLabel: true, isUninstallSheetPresented: $isUninstallSheetPresented)
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
                UninstallGameView(game: $game, isPresented: $isUninstallSheetPresented)
            }
        }
    }

    struct ButtonsView: View {
        @Binding var game: Game
        var withLabel = false
        @ObservedObject private var operation: GameOperation = .shared
        @EnvironmentObject var networkMonitor: NetworkMonitor

        var body: some View {
            if game.isInstalled {
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
            SubscriptedTextView({
                if case .epic = game.source {
                    return "Epic" // "Epic Games" is too verbose
                }

                return game.source.rawValue
            }())

            if let recent = try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed"),
               recent == game {
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
                    GameCardViewModel.SubscriptedInfoView(game: $game)
                        .lineLimit(1)
                }
            }
        }
    }

    // swiftlint:enable nesting
}

#Preview {
    LibraryView()
        .environmentObject(NetworkMonitor.shared)
}
