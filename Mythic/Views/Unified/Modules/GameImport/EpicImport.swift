//
//  Epic.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/1/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied
// Licensed under GNU GPL v3 or later.

import SwiftUI
import SwordRPC
import OSLog

extension GameImportView {
    struct Epic: View {
        @Binding var isPresented: Bool
        @State private var errorDescription: String = .init()
        @State private var isErrorAlertPresented = false

        @State private var installableGames: [Game] = .init()
        @State private var game: Game = Game(source: .epic, title: .init())
        @State private var path: String = .init()
        @State private var platform: Game.Platform = .macOS

        @State private var supportedPlatforms: [Game.Platform]?

        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true

        @State private var isOperating: Bool = false

        var body: some View {
            VStack {
                Form {
                    gameSelectionSection()
                    platformSelectionSection()
                    pathSelectionSection()
                    dlcToggleSection()
                    integrityToggleSection()
                }
                .formStyle(.grouped)
                .onChange(of: game) { fetchSupportedPlatforms(for: $1) }

                actionButtons()
            }
            .onAppear(perform: loadInstallableGames)
            .alert(isPresented: $isErrorAlertPresented, content: errorAlert)
            .onChange(of: isErrorAlertPresented) {
                if !$0 { errorDescription = .init() }
            }
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence = RichPresence()
                    presence.details = "Importing & Configuring \(platform.rawValue) game \"\(game.title)\""
                    presence.state = "Importing \(game.title)"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    return presence
                }())
            }
        }

        // MARK: - View Sections

        @ViewBuilder
        private func gameSelectionSection() -> some View {
            if !installableGames.isEmpty {
                Picker("Select a game:", selection: $game) {
                    ForEach(installableGames, id: \.self) { game in
                        Text(game.title)
                    }
                }
            } else {
                loadingRow(text: "Select a game:")
            }
        }

        @ViewBuilder
        private func platformSelectionSection() -> some View {
            if let platforms = supportedPlatforms {
                Picker("Choose the game's native platform:", selection: $platform) {
                    ForEach(platforms, id: \.self) { platform in
                        Text(platform.rawValue)
                    }
                }
            } else {
                loadingRow(text: "Choose the game's native platform:")
            }
        }

        @ViewBuilder
        private func pathSelectionSection() -> some View {
            HStack {
                VStack(alignment: .leading) {
                    Text("Where is the game located?")
                    Text(URL(filePath: path).prettyPath())
                        .foregroundStyle(.placeholder)
                }

                Spacer()

                if !files.isReadableFile(atPath: path) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .help("File/Folder is not readable by Mythic.")
                }

                Button("Browse...") { browseForGameLocation() }
            }
        }

        private func dlcToggleSection() -> some View {
            Toggle("Import with DLCs", isOn: $withDLCs)
        }

        private func integrityToggleSection() -> some View {
            Toggle("Verify the game's integrity", isOn: $checkIntegrity)
        }

        // MARK: - Buttons and Actions

        private func actionButtons() -> some View {
            HStack {
                Button("Cancel", role: .cancel) { isPresented = false }

                Spacer()

                if isOperating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(0.5)
                }

                Button("Done") { performGameImport() }
                    .disabled(isFormInvalid)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }

        // MARK: - Helper Methods

        private var isFormInvalid: Bool {
            path.isEmpty || game.title.isEmpty || supportedPlatforms == nil || isOperating
        }

        private func loadingRow(text: String) -> some View {
            HStack {
                Text(text)
                Spacer()
                ProgressView().controlSize(.small)
            }
        }

        private func browseForGameLocation() {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = []
            openPanel.canChooseDirectories = true
            openPanel.allowedContentTypes = platform == .macOS ? [.application] : [.exe]
            openPanel.allowsMultipleSelection = false

            if openPanel.runModal() == .OK {
                path = openPanel.urls.first?.path ?? ""
            }
        }

        private func fetchSupportedPlatforms(for game: Game) {
            if let fetchedPlatforms = try? Legendary.getGameMetadata(game: game)?["asset_infos"].dictionary {
                supportedPlatforms = fetchedPlatforms.keys.compactMap { key in
                    switch key {
                    case "Windows": return .windows
                    case "Mac": return .macOS
                    default: return nil
                    }
                }
                platform = supportedPlatforms?.first ?? .macOS
            } else {
                Logger.app.info("Unable to fetch supported platforms for \(game.title).")
                supportedPlatforms = Game.Platform.allCases
            }
        }

        private func loadInstallableGames() {
            Task {
                let games = try? Legendary.getInstallable()
                guard let games = games, !games.isEmpty else { return }
                installableGames = games.filter { (try? !Legendary.getInstalledGames().contains($0)) ?? true }
                game = installableGames.first ?? Game(source: .epic, title: "")
                withAnimation { isOperating = false }
            }
        }

        private func performGameImport() {
            withAnimation { isOperating = true }

            Task(priority: .userInitiated) {
                try? await Legendary.command(
                    arguments: [
                        "import",
                        checkIntegrity ? nil : "--disable-check",
                        withDLCs ? "--with-dlcs" : "--skip-dlcs",
                        "--platform", platform.rawValue,
                        game.id, path
                    ].compactMap { $0 },
                    identifier: "epicImport"
                ) { output in
                    handleCommandOutput(output)
                }
            }
        }

        private func handleCommandOutput(_ output: Legendary.CommandOutput) {
            if output.stderr.contains("INFO: Game \"\(game.title)\" has been imported.") {
                isPresented = false
            } else if let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: output.stderr) {
                withAnimation { isOperating = false }
                errorDescription = String(match[2].substring ?? "Unknown Error — perhaps the game is corrupted.")
                isErrorAlertPresented = true
            }
        }

        private func resetErrorState() {
            errorDescription = ""
        }

        private func errorAlert() -> Alert {
            Alert(
                title: Text("Error importing game \"\(game.title)\"."),
                message: Text(errorDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    GameImportView.Epic(isPresented: .constant(true))
}
