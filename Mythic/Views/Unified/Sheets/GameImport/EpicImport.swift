//
//  Epic.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/1/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import SwordRPC
import OSLog
import UniformTypeIdentifiers

// FIXME: refactor: warning ‼️ below code may need a cleanup
extension GameImportView {
    struct Epic: View {
        @Binding var isPresented: Bool
        @State private var errorDescription: String = .init()
        @State private var isErrorAlertPresented = false

        @State private var game: Game = .init(id: .init(),
                                              title: .init(),
                                              installationState: .uninstalled)

        @State private var platform: Game.Platform = .macOS
        @State private var location: URL = .temporaryDirectory

        private var installableGames: [Game] {
            Game.store.games
                .sorted(by: { $0.title < $1.title })
                .filter({ $0.storefront == .epicGames })
                .filter({ $0.installationState == .uninstalled })
        }

        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true

        @State private var isImageEmpty: Bool = true

        @State private var isOperating: Bool = false

        @State private var isGameLocationFileImporterPresented: Bool = false

        private let modifyingStatusLock: NSLock = .init()
        private func updateGameInstallationState(location: URL?, platform: Game.Platform?) {
            modifyingStatusLock.withLock {
                game.installationState = .installed(location: location ?? self.location,
                                                    platform: platform ?? self.platform)
            }
        }

        var body: some View {
            VStack {
                HStack {
                    GameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                        .padding([.top, .leading])

                    Form {
                        Picker("Game",
                               systemImage: "gamecontroller",
                               selection: $game) {
                            ForEach(installableGames, id: \.self) { game in
                                Text(game.title)
                            }
                        }
                        .onAppear(perform: { game = installableGames.first ?? game })

                        Picker("Platform",
                               systemImage: "desktopcomputer.and.arrow.down",
                               selection: $platform) {
                            ForEach(game.supportedPlatforms, id: \.self) { platform in
                                Text(platform.description)
                            }
                        }
                        // use onChange, because platform requires game as a dependency
                        .onChange(of: game, { platform = $1.supportedPlatforms.first ?? platform })

                        HStack {
                            VStack(alignment: .leading) {
                                Label("Location", systemImage: "folder")
                                if location != .temporaryDirectory {
                                    Text(location.prettyPath)
                                        .foregroundStyle(.placeholder)
                                }
                            }

                            if !files.isReadableFile(atPath: location.path) {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .help("File/Folder is not readable by Mythic.")
                            }

                            Spacer()

                            Button("Browse...") {
                                isGameLocationFileImporterPresented = true
                            }
                            .fileImporter(
                                isPresented: $isGameLocationFileImporterPresented,
                                allowedContentTypes: allowedContentTypes(for: platform)
                            ) { result in
                                if case .success(let success) = result {
                                    location = success
                                }
                            }
                        }

                        Toggle("Import with DLCs", systemImage: "plus", isOn: $withDLCs)

                        Toggle("Verify game files' integrity", systemImage: "checkmark.app", isOn: $checkIntegrity)
                    }
                    .formStyle(.grouped)
                }

                HStack {
                    Button("Cancel", role: .cancel) { isPresented = false }

                    Spacer()

                    OperationButton("Done",
                                    operating: $isOperating,
                                    successful: .constant(nil),
                                    placement: .leading,
                                    action: performGameImport)
                    .disabled(location == .temporaryDirectory)
                    .disabled(game.supportedPlatforms.isEmpty)
                    .disabled(isOperating)
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
            }
            .alert("Error importing game \"\(game.title)\".",
                   isPresented: $isErrorAlertPresented,
                   presenting: errorDescription) { _ in
                if #available(macOS 26.0, *) {
                    Button("OK", role: .close, action: {})
                } else {
                    Button("OK", role: .cancel, action: {})
                }
            } message: { description in
                Text(description)
            }
            .onChange(of: isErrorAlertPresented) {
                if !$1 { errorDescription = .init() }
            }
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence = RichPresence()
                    presence.details = "Importing & Configuring \"\(game.title)\"."
                    presence.state = "Importing \(game.title)"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    return presence
                }())
            }
        }

        private func allowedContentTypes(for platform: Game.Platform) -> [UTType] {
            switch platform {
            case .macOS:    [.application]
            case .windows:  [.exe]
            }
        }

        private func performGameImport() {
            withAnimation { isOperating = true }
        }
    }
}

#Preview {
    GameImportView.Epic(isPresented: .constant(true))
}
