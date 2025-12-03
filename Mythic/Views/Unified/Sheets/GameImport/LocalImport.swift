//
//  Local.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/1/2024.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import SwordRPC
import Shimmer
import UniformTypeIdentifiers
import OSLog

// FIXME: unify with GameImportView.Epic
extension GameImportView {
    struct Local: View {
        @Bindable var gameDataStore: GameDataStore = .shared
        
        @Binding var isPresented: Bool

        @State private var game: LocalGame = .init(title: .init(),
                                                   installationState: .uninstalled)

        @State private var platform: Game.Platform = .macOS
        @State private var location: URL = .temporaryDirectory
        
        @State private var isImageEmpty: Bool = true
        
        @State private var isGameLocationFileImporterPresented: Bool = false
        
        private func updateGameTitle() {
            guard location != .temporaryDirectory, game.title.isEmpty else { return }
            switch platform {
            case .macOS:
                if let bundle = Bundle(path: location.path),
                   let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                    game.title = bundleName
                }
            case .windows:
                game.title = location.lastPathComponent.replacingOccurrences(of: ".exe", with: "")
            }
        }
        
        var body: some View {
            VStack {
                HStack {
                    VStack {
                        GameImageCard(url: game.verticalImageURL, isImageEmpty: .constant(false))
                            .aspectRatio(3/4, contentMode: .fit)
                        
                        Label("Images with a 3:4 aspect ratio are preferred.",
                              systemImage: "info")
                            .symbolVariant(.circle)
                            .foregroundStyle(.secondary)
                            .ignoresSafeArea()
                            .font(.footnote)
                    }
                    .padding([.leading, .top])

                    VStack {
                        Form {
                            TextField("Title", text: $game.title)

                            Picker("Platform", systemImage: "gamecontroller", selection: $platform) {
                                ForEach(Game.Platform.allCases, id: \.self) {
                                    Text($0.description)
                                }
                            }
                            .onChange(of: platform) {
                                game.installationState = .installed(location: location, platform: $1)
                            }

                            // FIXME: boilerplate, shared with GameImportView.Epic
                            HStack {
                                VStack(alignment: .leading) {
                                    Label("Location", systemImage: "folder")
                                    if location != .temporaryDirectory {
                                        Text(location.prettyPath)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if !FileManager.default.isReadableFile(atPath: location.path) {
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
                                    allowedContentTypes: platform.allowedExecutableContentTypes
                                ) { result in
                                    if case .success(let success) = result {
                                        location = success
                                    }
                                }
                            }
                            .onChange(of: location) {
                                updateGameTitle()
                                game.installationState = .installed(location: $1, platform: platform)
                            }

                            GameCard.ImageURLModifierView(
                                game: .init(get: { return game as Game },
                                            set: {
                                                if let castGame = $0 as? LocalGame {
                                                    game = castGame
                                                }
                                            }),
                                imageURL: $game._verticalImageURL
                            )
                        }
                        .formStyle(.grouped)
                    }
                }

                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }

                    Spacer()

                    Button("Done") {
                        gameDataStore.library.insert(game)
                        isPresented = false
                    }
                    .disabled(game.installationState == .uninstalled)
                    .disabled(game.title.isEmpty)
                    .disabled(location == .temporaryDirectory)
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
            }
        }
    }
}

#Preview {
    GameImportView.Local(isPresented: .constant(true))
}
