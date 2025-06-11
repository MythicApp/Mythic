//
//  GameCardVM.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/20/24.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import Foundation
import SwiftUI
import SwiftyJSON
import Shimmer

@Observable final class GameCardVM: ObservableObject {

    // swiftlint:disable nesting
    struct SharedViews {
        struct ShimmerView: View {
            var body: some View {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .shimmering(
                        animation: .easeInOut(duration: 1).repeatForever(autoreverses: false),
                        bandSize: 1
                    )
            }
        }

        struct Buttons {
            struct PlayButton: View {
                @Binding var game: Game
                @ObservedObject private var operation: GameOperation = .shared

                @State private var isLaunchErrorAlertPresented = false
                @State private var launchError: Error?

                var isPlayDisabled: Bool {
                    game.path?.isEmpty ?? true
                    || !files.fileExists(atPath: game.path ?? "")
                    || operation.runningGames.contains(game)
                    || Wine.containerURLs.isEmpty
                }

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
                        Image(systemName: "play")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .help(game.path != nil ? "Play \"\(game.title)\"" : "Unable to locate \(game.title) at its specified path (\(game.path ?? "Unknown"))")
                    .disabled(isPlayDisabled)
                    .alert(isPresented: $isLaunchErrorAlertPresented) {
                        Alert(
                            title: Text("Error launching \"\(game.title)\"."),
                            message: Text(launchError?.localizedDescription ?? "Unknown Error.")
                        )
                    }
                }
            }

            struct EngineInstallButton: View {
                @Binding var game: Game
                @EnvironmentObject var networkMonitor: NetworkMonitor

                var body: some View {
                    Button { // TODO: convert onboarding engine installer into standalone sheet
                        let app = MythicApp() // FIXME: is this dangerous or just stupid
                        app.onboardingPhase = .engineDisclaimer // FIXME: doesnt even work lol
                        app.isOnboardingPresented = true
                    } label: {
                        Image(systemName: "arrow.down.circle.dotted")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .disabled(!networkMonitor.isConnected)
                    .help("Install Mythic Engine")
                }
            }

            struct VerificationButton: View {
                @Binding var game: Game
                @EnvironmentObject var networkMonitor: NetworkMonitor
                @ObservedObject private var operation: GameOperation = .shared

                var body: some View {
                    Button {
                        operation.queue.append(GameOperation.InstallArguments(game: game, platform: game.platform!, type: .repair))
                    } label: {
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .disabled(networkMonitor.epicAccessibilityState != .accessible)
                    .help("Game verification is required for \"\(game.title)\".")
                }
            }
            struct UpdateButton: View {
                @Binding var game: Game
                @EnvironmentObject var networkMonitor: NetworkMonitor
                @ObservedObject private var operation: GameOperation = .shared

                var body: some View {
                    Button {
                        operation.queue.append(GameOperation.InstallArguments(game: game, platform: game.platform!, type: .update))
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .disabled(networkMonitor.epicAccessibilityState != .accessible || operation.runningGames.contains(game))
                    .help("Update \"\(game.title)\"")
                }
            }

            struct SettingsButton: View {
                @Binding var game: Game

                @State private var isGameSettingsSheetPresented = false

                var body: some View {
                    Button {
                        isGameSettingsSheetPresented = true
                    } label: {
                        Image(systemName: "gear")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .sheet(isPresented: $isGameSettingsSheetPresented) {
                        GameSettingsView(game: $game, isPresented: $isGameSettingsSheetPresented)
                            .padding()
                            .frame(minWidth: 750)
                    }
                    .help("Modify settings for \"\(game.title)\"")
                }
            }

            struct FavouriteButton: View {
                @Binding var game: Game

                @State private var hoveringOverFavouriteButton = false
                @State private var animateFavouriteIcon = false

                var body: some View {
                    Button {
                        game.isFavourited.toggle()
                        withAnimation { animateFavouriteIcon = game.isFavourited }
                    } label: {
                        Image(systemName: "star")
                            .symbolVariant(animateFavouriteIcon ? (hoveringOverFavouriteButton ? .slash.fill : .fill) : .none)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .onHover { hoveringOverFavouriteButton = $0 }
                    .help("Favourite \"\(game.title)\"")
                    .task { animateFavouriteIcon = game.isFavourited }
                    .shadow(color: .secondary, radius: animateFavouriteIcon ? 20 : 0)
                }
            }

            struct DeleteButton: View {
                @Binding var game: Game
                @ObservedObject private var operation: GameOperation = .shared

                @State private var isUninstallSheetPresented = false
                @State private var hoveringOverDestructiveButton = false

                var isDeleteDisabled: Bool {
                    operation.current?.game != nil || operation.runningGames.contains(game)
                }

                var body: some View {
                    Button {
                        isUninstallSheetPresented = true
                    } label: {
                        // not using terenary operator to implicitly leave foregroundstyle unmodified
                        if hoveringOverDestructiveButton {
                            Image(systemName: "xmark.bin")
                                .padding(5)
                                .foregroundStyle(.red)
                        } else {
                            Image(systemName: "xmark.bin")
                                .padding(5)
                        }
                    }
                    .clipShape(.circle)
                    .disabled(isDeleteDisabled)
                    .help("Delete \"\(game.title)\"")
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveringOverDestructiveButton = hovering
                        }
                    }
                    .sheet(isPresented: $isUninstallSheetPresented) {
                        UninstallViewEvo(game: $game, isPresented: $isUninstallSheetPresented)
                    }
                }
            }

            struct InstallButton: View {
                @Binding var game: Game
                @EnvironmentObject var networkMonitor: NetworkMonitor
                @ObservedObject private var operation: GameOperation = .shared

                @State private var isInstallSheetPresented = false

                var body: some View {
                    Button {
                        isInstallSheetPresented = true
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .padding(5)
                    }
                    .clipShape(.circle)
                    .disabled(networkMonitor.epicAccessibilityState != .accessible || operation.queue.contains(where: { $0.game == game }))
                    .help("Download \"\(game.title)\"")
                    .sheet(isPresented: $isInstallSheetPresented) {
                        InstallViewEvo(game: $game, isPresented: $isInstallSheetPresented)
                    }
                }
            }
        }

        struct ButtonsView: View {
            @Binding var game: Game
            @ObservedObject private var operation: GameOperation = .shared
            @EnvironmentObject var networkMonitor: NetworkMonitor

            private func needsVerification(for game: Game) -> Bool {
                if let json = try? JSON(data: Data(contentsOf: URL(filePath: "\(Legendary.configLocation)/installed.json"))) {
                    return json[game.id]["needs_verification"].boolValue
                }
                return false
            }

            var body: some View {
                HStack {
                    if let currentGame = operation.current?.game, currentGame.id == game.id {
                        GameInstallProgressView()
                            .padding(.horizontal)
                    } else if game.isInstalled {
                        installedGameButtons
                    } else {
                        Buttons.InstallButton(game: $game)
                    }
                }
            }

            @ViewBuilder
            var installedGameButtons: some View {
                    if case .epic = game.source, needsVerification(for: game) {
                        Buttons.VerificationButton(game: $game)
                    } else {
                        if game.isLaunching {
                            ProgressView()
                                .controlSize(.small)
                                .clipShape(.circle)
                                .padding(5)
                        } else {
                            if case .windows = game.platform, !Engine.exists {
                                Buttons.EngineInstallButton(game: $game, networkMonitor: _networkMonitor)
                            } else {
                                Buttons.PlayButton(game: $game)
                            }
                        }

                        if game.needsUpdate {
                            Buttons.UpdateButton(game: $game, networkMonitor: _networkMonitor)
                        }

                        Buttons.SettingsButton(game: $game)
                        Buttons.FavouriteButton(game: $game)
                        Buttons.DeleteButton(game: $game)
                    }
            }
        }

        struct SubscriptedInfoView: View {
            @Binding var game: Game

            var body: some View {
                SubscriptedTextView(game.source.rawValue)

                if let recent = try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed"),
                   recent == game {
                    SubscriptedTextView("Recent")
                }
            }
        }

        struct Template: View {
            var body: some View {
                do {}
            }
        }

        // swiftlint:enable nesting
    }
}

#Preview {
    LibraryView()
        .environmentObject(NetworkMonitor.shared)
}
