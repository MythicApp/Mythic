//
//  GameCardVM.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/20/24.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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

        struct ButtonsView: View {
            @Binding var game: Game
            @EnvironmentObject var networkMonitor: NetworkMonitor
            @ObservedObject private var operation: GameOperation = .shared

            @State private var isGameSettingsSheetPresented = false
            @State private var isUninstallSheetPresented = false
            @State private var isInstallSheetPresented = false
            @State private var isStopGameModificationAlertPresented = false
            @State private var isLaunchErrorAlertPresented = false
            @State private var launchError: Error?

            @State private var hoveringOverDestructiveButton = false
            @State private var animateFavouriteIcon = false

            var body: some View {
                HStack {
                    if let currentGame = operation.current?.game, currentGame.id == game.id {
                        GameInstallProgressView()
                            .padding(.horizontal)
                    } else if game.isInstalled {
                        installedGameButtons
                    } else {
                        installButton
                    }
                }
            }

            @ViewBuilder
            var installedGameButtons: some View {
                if case .epic = game.source, needsVerification(for: game) {
                    verificationButton
                } else {
                    if game.isLaunching {
                        ProgressView()
                            .controlSize(.small)
                            .clipShape(.circle)
                            .foregroundStyle(.white)
                            .padding(5)
                    } else {
                        if case .windows = game.platform, !Engine.exists {
                            engineInstallButton
                        } else {
                            playButton
                        }
                    }
                    if game.needsUpdate {
                        updateButton
                    }
                    settingsButton
                    favouriteButton
                    deleteButton
                }
            }

            var engineInstallButton: some View {
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

            private func needsVerification(for game: Game) -> Bool {
                if let json = try? JSON(data: Data(contentsOf: URL(filePath: "\(Legendary.configLocation)/installed.json"))) {
                    return json[game.id]["needs_verification"].boolValue
                }
                return false
            }

            var verificationButton: some View {
                Button {
                    operation.queue.append(GameOperation.InstallArguments(game: game, platform: game.platform!, type: .repair))
                } label: {
                    Image(systemName: "checkmark.circle.badge.questionmark")
                        .padding(5)
                }
                .clipShape(.circle)
                .disabled(!networkMonitor.isEpicAccessible)
                .help("Game verification is required for \"\(game.title)\".")
            }

            var playButton: some View {
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
                .disabled(isPlayDisabled)
                .alert(isPresented: $isLaunchErrorAlertPresented) {
                    Alert(
                        title: Text("Error launching \"\(game.title)\"."),
                        message: Text(launchError?.localizedDescription ?? "Unknown Error.")
                    )
                }
            }

            var isPlayDisabled: Bool {
                game.path?.isEmpty ?? true || !files.fileExists(atPath: game.path ?? "") || operation.runningGames.contains(game) || Wine.containerURLs.isEmpty
            }

            var updateButton: some View {
                Button {
                    operation.queue.append(GameOperation.InstallArguments(game: game, platform: game.platform!, type: .update))
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .padding(5)
                }
                .clipShape(.circle)
                .disabled(!networkMonitor.isEpicAccessible || operation.runningGames.contains(game))
                .help("Update \"\(game.title)\"")
            }

            var settingsButton: some View {
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

            var favouriteButton: some View {
                Button {
                    game.isFavourited.toggle()
                    withAnimation { animateFavouriteIcon = game.isFavourited }
                } label: {
                    Image(systemName: animateFavouriteIcon ? "star.fill" : "star")
                        .padding(5)
                }
                .clipShape(.circle)
                .help("Favourite \"\(game.title)\"")
                .task { animateFavouriteIcon = game.isFavourited }
                .shadow(color: .secondary, radius: animateFavouriteIcon ? 20 : 0)
                .symbolEffect(.bounce, value: animateFavouriteIcon)
            }

            var deleteButton: some View {
                Button {
                    isUninstallSheetPresented = true
                } label: {
                    Image(systemName: "xmark.bin")
                        .padding(5)
                        .foregroundStyle(hoveringOverDestructiveButton ? .red : .secondary)
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

            var isDeleteDisabled: Bool {
                operation.current?.game != nil || operation.runningGames.contains(game)
            }

            var installButton: some View {
                Button {
                    isInstallSheetPresented = true
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .padding(5)
                }
                .clipShape(.circle)
                .disabled(!networkMonitor.isEpicAccessible || operation.queue.contains(where: { $0.game == game }))
                .help("Download \"\(game.title)\"")
                .sheet(isPresented: $isInstallSheetPresented) {
                    InstallViewEvo(game: $game, isPresented: $isInstallSheetPresented)
                        .padding()
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
