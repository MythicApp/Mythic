//
//  EpicGameInstallationView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 27/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI
import OSLog

struct EpicGameInstallationView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @Bindable private var operationManager: GameOperationManager = .shared
    @AppStorage("installBaseURL") private var baseURL: URL = Bundle.appGames!

    @State private var isInstallLocationFileImporterPresented: Bool = false

    @State var platform: Game.Platform = .macOS

    @State var installSizeInBytes: Int64?
    var freeSpaceInBytes: Int64? {
        let filesystemAttributes = try? files.attributesOfFileSystem(forPath: Bundle.appHome?.path ?? "/")
        return (filesystemAttributes?[.systemFreeSize] as? Int64)
    }
    @State private var isFreeSpaceAlertPresented: Bool = false

    @State private var isRetrievingSupportedPlatforms: Bool = false
    @State private var supportedPlatforms: [Game.Platform]?

    // epic-specific variables
    @State var optionalPacks: [String: String]?
    @State var selectedOptionalPacks: Set<String> = .init()
    @State var fetchingOptionalPacks: Bool = false

    private func fetchOptionalPacks() {
        guard let game = game as? EpicGamesGame else { return }
        Task {
            fetchingOptionalPacks = true
            defer { fetchingOptionalPacks = false }
            (installSizeInBytes, optionalPacks) = await Legendary.fetchPreInstallationMetadata(game: game, platform: platform)
        }
    }

    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            HStack {
                GameCard.ImageCard(game: $game, isImageEmpty: .constant(false))

                VStack {
                    Text("Install \(game.description)")
                        .font(.title)
                        .bold()

                    if let storefront = game.storefront {
                        SubscriptedTextView(storefront.description)
                    }

                    if let optionalPacks = optionalPacks,
                       !optionalPacks.isEmpty {
                        Text("(Selective downloads supported.)")
                            .font(.footnote)
                            .foregroundStyle(.placeholder)

                        Form {
                            ForEach(optionalPacks.sorted(by: { $0.key < $1.key }), id: \.key) { tag, name in
                                Toggle(
                                    isOn: Binding(
                                        get: { selectedOptionalPacks.contains(tag) },
                                        set: { newValue in
                                            if newValue {
                                                selectedOptionalPacks.insert(tag)
                                            } else {
                                                selectedOptionalPacks.remove(tag)
                                            }
                                        }
                                    )
                                ) {
                                    Text(name)
                                    Text(tag)
                                        .font(.footnote)
                                        .foregroundStyle(.placeholder)
                                }
                            }
                        }
                        .formStyle(.grouped)
                    }

                    Form {
                        HStack {
                            VStack(alignment: .leading) {
                                Label("Installation Directory", systemImage: "folder")

                                Text(baseURL.prettyPath)
                                    .foregroundStyle(.placeholder)
                            }

                            Spacer()

                            if !files.isWritableFile(atPath: baseURL.path) {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .help("Folder is not writable.")
                            }

                            // TODO: unify
                            Button("Browse...") {
                                isInstallLocationFileImporterPresented = true
                            }
                            .fileImporter(
                                isPresented: $isInstallLocationFileImporterPresented,
                                allowedContentTypes: [.folder]
                            ) { result in
                                if case .success(let url) = result {
                                    baseURL = url
                                }
                            }
                        }

                        // FIXME: shared with EpicImport
                        Picker(
                            "Platform",
                            systemImage: "desktopcomputer.and.arrow.down",
                            selection: $platform
                        ) {
                            ForEach(supportedPlatforms ?? .init(), id: \.self) { platform in
                                Text(platform.description)
                            }
                        }
                        .task(priority: .userInitiated) {
                            isRetrievingSupportedPlatforms = true
                            if let retrievedSupportedPlatforms = game.getSupportedPlatforms() {
                                supportedPlatforms = Array(retrievedSupportedPlatforms)
                            }
                            isRetrievingSupportedPlatforms = false
                        }
                        .withOperationStatus(
                            operating: $isRetrievingSupportedPlatforms,
                            successful: .constant(nil),
                            observing: $supportedPlatforms,
                            action: { // update platform value so picker is never undefined
                                // sort to prioritise macOS first
                                let platforms = supportedPlatforms?.sorted(by: { $0 == .macOS && $1 != .macOS })
                                platform = platforms?.first ?? platform
                            }
                        )
                    }
                    .formStyle(.grouped)
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }

                Spacer()

                if let byteCount = installSizeInBytes {
                    Text(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))
                }
                OperationButton(
                    "Done",
                    operating: $fetchingOptionalPacks,
                    successful: .constant(nil),
                    placement: .leading
                ) {
                    Task { @MainActor [game] in
                        if let epicGamesGame = game as? EpicGamesGame {
                            try? await EpicGamesGameManager.install(game: epicGamesGame,
                                                                    forPlatform: platform,
                                                                    qualityOfService: .default,
                                                                    optionalPacks: Array(selectedOptionalPacks),
                                                                    gameDirectoryURL: baseURL)
                        }
                    }
                }
                .disabled(supportedPlatforms == nil)
                .disabled(fetchingOptionalPacks)
                .onAppear(perform: { fetchOptionalPacks() })
                .onChange(of: game, { fetchOptionalPacks() })
                .buttonStyle(.borderedProminent)
            }
            .onChange(of: isPresented) { _, newValue in // don't use .onDisappear, it interferes with runningcommands' task handling
                guard !newValue else { return }
                Task { @MainActor in
                    await Legendary.RunningCommands.shared.stop(id: "parseOptionalPacks")
                }
            }
            .onDisappear {
                Task {
                    await Legendary.RunningCommands.shared.stop(id: "parseOptionalPacks")
                }
            }
        }
        .navigationTitle("Install \(game.description)")
    }
}

#Preview {
    // this will crash if you don't have fortnite in your library or are signed out
    EpicGameInstallationView(
        game: .constant(Game.store.library.first(where: { $0.id == "Fortnite" })!),
        isPresented: .constant(true)
    )
    .padding()
}
