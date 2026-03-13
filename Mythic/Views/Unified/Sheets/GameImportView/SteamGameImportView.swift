//
//  SteamGameImportView.swift
//  Mythic
//
//  Created on 12/3/2026.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import UniformTypeIdentifiers

struct SteamGameImportView: View {
    @Bindable var gameDataStore: GameDataStore = .shared

    @Binding var isPresented: Bool

    @State private var game: SteamGame = .init(title: "", installationState: .uninstalled)
    @State private var discoveredGames: [SteamGame] = []

    @State private var selectedContainerURL: URL? = Wine.containerURLs.first
    @State private var steamRootURL: URL?

    @State private var isImageEmpty: Bool = false
    @State private var isSteamRootImporterPresented: Bool = false

    @State private var isLoadingGames: Bool = false
    @State private var isImporting: Bool = false
    @State private var importSuccessful: Bool?

    @State private var importError: Error?
    @State private var isImportErrorAlertPresented: Bool = false

    private var refreshKey: String {
        "\(selectedContainerURL?.path ?? "")|\(steamRootURL?.path ?? "")"
    }

    private var selectedGameLocationDescription: String {
        guard case .installed(let location, _) = game.installationState else { return "Unknown" }
        return location.prettyPath
    }

    private var isSelectedSteamRootInContainer: Bool {
        guard let steamRootURL, let selectedContainerURL else { return false }
        return steamRootURL.standardizedFileURL.path.hasPrefix(selectedContainerURL.standardizedFileURL.path)
    }

    private var steamExecutableURL: URL? {
        steamRootURL.map { Steam.windowsExecutableURL(in: $0) }
    }

    private var doesSelectedSteamRootContainClient: Bool {
        guard let steamExecutableURL else { return false }
        return FileManager.default.fileExists(atPath: steamExecutableURL.path)
    }

    private var isReadyToImport: Bool {
        steamRootURL != nil
            && selectedContainerURL != nil
            && isSelectedSteamRootInContainer
            && doesSelectedSteamRootContainClient
            && discoveredGames.contains(where: { $0 == game })
    }

    private func suggestedContainerURL(for steamRootURL: URL) -> URL? {
        Wine.containerURLs.first(where: { steamRootURL.standardizedFileURL.path.hasPrefix($0.standardizedFileURL.path) })
    }

    @MainActor
    private func resetDiscoveredGames() {
        discoveredGames = []
        game = SteamGame(title: "", installationState: .uninstalled, containerURL: selectedContainerURL)
    }

    @MainActor
    private func refreshDiscoveredGames() async {
        guard let steamRootURL, let selectedContainerURL else {
            resetDiscoveredGames()
            return
        }

        isLoadingGames = true
        defer { isLoadingGames = false }

        do {
            let fetchedGames = try Steam.getInstalledGames(in: steamRootURL, containerURL: selectedContainerURL)
                .sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })

            discoveredGames = fetchedGames

            if let refreshedSelection = fetchedGames.first(where: { $0.id == game.id }) {
                game = refreshedSelection
            } else {
                game = fetchedGames.first ?? SteamGame(title: "", installationState: .uninstalled, containerURL: selectedContainerURL)
            }
        } catch {
            resetDiscoveredGames()
            importError = error
            isImportErrorAlertPresented = true
        }
    }

    var body: some View {
        VStack {
            HStack {
                GameImageCard(game: game, url: game.verticalImageURL, isImageEmpty: $isImageEmpty)
                    .aspectRatio(3/4, contentMode: .fit)
                    .padding([.top, .leading])

                Form {
                    if Wine.containerURLs.isEmpty {
                        ContentUnavailableView(
                            "No containers available.",
                            systemImage: "cube.transparent",
                            description: Text("Create a Wine container before importing a Windows Steam game.")
                        )
                    } else {
                        Picker("Wine Container", systemImage: "cube", selection: $selectedContainerURL) {
                            ForEach(Wine.containerObjects) { container in
                                Text(container.name)
                                    .tag(Optional(container.url))
                            }
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                Label("Steam Root", systemImage: "folder")
                                Text(steamRootURL?.prettyPath ?? "Select the Steam folder inside a Wine container")
                                    .foregroundStyle(.secondary)
                            }

                            if steamRootURL != nil && !isSelectedSteamRootInContainer {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .help("The selected Steam root must live inside the chosen Wine container.")
                            } else if steamRootURL != nil && !doesSelectedSteamRootContainClient {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .help("The selected Steam folder must contain steam.exe.")
                            }

                            Spacer()

                            Button("Browse...") {
                                isSteamRootImporterPresented = true
                            }
                            .fileImporter(
                                isPresented: $isSteamRootImporterPresented,
                                allowedContentTypes: [.folder]
                            ) { result in
                                if case .success(let selectedURL) = result {
                                    let normalizedURL = selectedURL.standardizedFileURL
                                    steamRootURL = normalizedURL
                                    if let suggestedContainerURL = suggestedContainerURL(for: normalizedURL) {
                                        selectedContainerURL = suggestedContainerURL
                                    }
                                }
                            }
                        }
                        .help("Select the Windows Steam folder that contains steam.exe and steamapps.")

                        Picker("Game", systemImage: "gamecontroller", selection: $game) {
                            ForEach(discoveredGames) { game in
                                Text(game.title)
                                    .tag(game)
                            }
                        }
                        .disabled(discoveredGames.isEmpty)
                        .withOperationStatus(
                            operating: $isLoadingGames,
                            successful: .constant(nil),
                            observing: .constant(discoveredGames)
                        ) { }

                        HStack {
                            VStack(alignment: .leading) {
                                Label("Detected Install", systemImage: "shippingbox")
                                Text(selectedGameLocationDescription)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        Label("Import registers an already-installed Windows Steam game; it does not copy files.",
                              systemImage: "info")
                        .symbolVariant(.circle)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    }
                }
                .formStyle(.grouped)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }

                Spacer()

                OperationButton(
                    "Done",
                    operating: $isImporting,
                    successful: $importSuccessful,
                    placement: .leading
                ) {
                    guard let steamRootURL else { return }

                    do {
                        try await SteamGameManager.importGame(game, in: steamRootURL, platform: .windows)
                        importSuccessful = true
                        isPresented = false
                    } catch {
                        importSuccessful = false
                        importError = error
                        isImportErrorAlertPresented = true
                    }
                }
                .disabled(!isReadyToImport)
                .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .bottom])
        }
        .alert("Error importing Steam game.",
               isPresented: $isImportErrorAlertPresented,
               presenting: importError) { _ in
            if #available(macOS 26.0, *) {
                Button("OK", role: .close, action: {})
            } else {
                Button("OK", role: .cancel, action: {})
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .task(id: refreshKey) {
            await refreshDiscoveredGames()
        }
    }
}

#Preview {
    SteamGameImportView(isPresented: .constant(true))
}
