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

        @State private var installableGames: [Game] = .init()
        @State private var supportedPlatforms: [Game.Platform]?
        @State private var game: Game = .init(id: .init(),
                                              title: .init(),
                                              source: .epic,
                                              platform: .macOS)

        @State private var gamePlatform: Game.Platform = .macOS
        @State private var gameLocation: URL? = nil

        @State private var isFetchingInstallableGames: Bool = false
        @State private var isFetchingGamePlatforms: Bool = false

        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true

        @State private var isImageEmpty: Bool = true

        @State private var isOperating: Bool = false

        @State private var isGameLocationFileImporterPresented: Bool = false

        func fetchSupportedPlatforms() async {
            // TODO: next: legendary method for get platform
            guard let fetchedPlatforms = try? Legendary.getGameMetadata(game: game)?["asset_infos"].dictionary else { return }

            supportedPlatforms = fetchedPlatforms.keys.compactMap { Legendary.matchPlatform(for: $0) }
            gamePlatform = supportedPlatforms?.first ?? gamePlatform
        }

        func fetchSupportedGames() async {
            let installable = try? Legendary.getInstallable()
            let installed = try? Legendary.getInstalledGames()

            installableGames = installable?.filter({ !(installed?.contains($0) ?? false) }) ?? .init()
            game = installableGames.first ?? .init(id: "", title: "Unknown", source: .epic, platform: .macOS)
        }

        var body: some View {
            VStack {
                HStack {
                    GameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                        .padding([.top, .leading])

                    Form {
                        Picker("Select a game:", selection: $game) {
                            ForEach(installableGames, id: \.self) { game in
                                Text(game.title)
                            }
                        }
                        .withOperationStatus(
                            operating: $isFetchingInstallableGames,
                            successful: .constant(nil),
                            observing: $installableGames,
                            action: {} // only needs to show progressview
                        )

                        Picker("Choose the game's native platform:", selection: $gamePlatform) {
                            ForEach(supportedPlatforms ?? .init(), id: \.self) { platform in
                                Text(platform.rawValue)
                            }
                        }
                        .withOperationStatus(
                            operating: $isFetchingGamePlatforms,
                            successful: .constant(nil),
                            observing: $supportedPlatforms,
                            action: {} // only needs to show progressview
                        )
                        .task({ await fetchSupportedPlatforms() })
                        .onChange(of: game) {
                            Task { await fetchSupportedPlatforms() }
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Game Location")

                                if let location = gameLocation {
                                    Text(location.prettyPath)
                                        .foregroundStyle(.placeholder)
                                }
                            }

                            Spacer()

                            if let location = game.location,
                               !files.isReadableFile(atPath: location.path) {
                                Image(systemName: "questionmark.folder")
                                    .symbolVariant(.fill)
                                    .help("Mythic does not have access to this game's location.")
                            }

                            Button("Browse...") {
                                isGameLocationFileImporterPresented = true
                            }
                            .fileImporter(
                                isPresented: $isGameLocationFileImporterPresented,
                                allowedContentTypes: allowedContentTypes(for: gamePlatform)
                            ) { result in
                                if case .success(let success) = result {
                                    gameLocation = success
                                }
                            }
                        }

                        Toggle("Import with DLCs", isOn: $withDLCs)

                        Toggle("Verify game integrity", isOn: $checkIntegrity)
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
                    .disabled(gameLocation == nil)
                    .disabled(supportedPlatforms == nil)
                    .disabled(isOperating)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
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
                    presence.details = "Importing & Configuring \(gamePlatform.rawValue) game \"\(game.title)\""
                    presence.state = "Importing \(game.title)"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    return presence
                }())
            }
        }

        private func allowedContentTypes(for platform: Game.Platform) -> [UTType] {
            switch platform {
            case .macOS:
                return [.application]
            case .windows:
                return [.folder]
            }
        }

        private func performGameImport() {
            withAnimation { isOperating = true }

            Task { @MainActor in
                await Legendary.executeStreamed(
                    identifier: "epicImport",
                    arguments: [
                        "import",
                        checkIntegrity ? nil : "--disable-check",
                        withDLCs ? "--with-dlcs" : "--skip-dlcs",
                        "--platform", {
                            switch gamePlatform {
                            case .macOS: "Mac"
                            case .windows: "Windows"
                            }
                        }(),
                        game.id,
                        gameLocation?.path
                    ].compactMap { $0 },
                    onChunk: { chunk in
                        Task {
                            await MainActor.run {
                                if case .standardError = chunk.stream,
                                   chunk.output.contains("INFO: Game \"\(game.title)\" has been imported.") {
                                    isPresented = false
                                } else if let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: chunk.output) {
                                    withAnimation { isOperating = false }
                                    errorDescription = String(match[2].substring ?? "Unknown Error — perhaps the game is corrupted.")
                                    isErrorAlertPresented = true
                                }
                            }
                        }

                        return nil
                    }
                )
            }
        }
    }
}

#Preview {
    GameImportView.Epic(isPresented: .constant(true))
}
