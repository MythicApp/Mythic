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

extension GameImportView {
    struct Local: View {
        @Binding var isPresented: Bool

        @State private var game: Game = .init(source: .local, title: .init(), platform: .macOS, path: "")
        @State private var imageURLString: String = .init()
        @State private var title: String = .init()
        @State private var platform: Game.Platform = .macOS
        @State private var path: String = .init()

        @State private var isImageEmpty: Bool = true
        @State private var imageRefreshFlag: Bool = false

        @State private var isGameLocationFileImporterPresented: Bool = false

        var body: some View {
            VStack {
                HStack {
                    if !imageURLString.isEmpty {
                        VStack {
                            GameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)
                                .id(imageRefreshFlag)

                            Label("Images with a 3:4 aspect ratio fit the best.", systemImage: "info")
                                .symbolVariant(.circle)
                                .font(.footnote)
                                .foregroundStyle(.placeholder)
                        }
                        .padding([.leading, .top])
                    }

                    Form {
                        gameTitleTextField()
                        platformPicker()
                        gamePathInput()

                        GameCard.ImageURLModifierView(game: $game, imageURLString: $imageURLString)
                            .onChange(of: imageURLString, { imageRefreshFlag.toggle() })
                    }
                    .formStyle(.grouped)
                }

                actionButtons()
                    .padding()
                    .task(priority: .background) {
                        discordRPC.setPresence({
                            var presence = RichPresence()
                            presence.details = "Importing & Configuring \(platform.rawValue) game \"\(title)\""
                            presence.state = "Importing \(title)"
                            presence.timestamps.start = .now
                            presence.assets.largeImage = "macos_512x512_2x"
                            return presence
                        }())
                    }
            }
        }

        private func shimmerPlaceholder() -> some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.windowBackground)
                .shimmering(
                    animation: .easeInOut(duration: 1)
                        .repeatForever(autoreverses: false),
                    bandSize: 1
                )
        }

        private func gameTitleTextField() -> some View {
            TextField("What should we call this game?", text: $title)
                .onChange(of: title) { game.title = $1 }
        }

        private func platformPicker() -> some View {
            Picker("Choose the game's native platform:", selection: $platform) {
                ForEach(Game.Platform.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .onChange(of: platform) {
                game.platform = $1
                resetFormFields()
            }
            .task { game.platform = platform }
        }

        private func resetFormFields() {
            title = .init()
            path = .init()
        }

        private func gamePathInput() -> some View {
            HStack {
                VStack(alignment: .leading) {
                    Text("Choose the game's install location:")
                    Text(URL(filePath: path).prettyPath)
                        .foregroundStyle(.placeholder)
                }

                if !files.isReadableFile(atPath: path), !path.isEmpty {
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
                        path = success.path(percentEncoded: false)
                    }
                }
            }
            .onChange(of: path) {
                updateGameTitle()
                game.path = $1
            }
        }

        private func allowedContentTypes(for platform: Game.Platform) -> [UTType] {
            switch platform {
            case .macOS:
                return [.application]
            case .windows:
                return [.exe]
            }
        }

        private func updateGameTitle() {
            if !path.isEmpty, title.isEmpty {
                switch platform {
                case .macOS:
                    if let bundle = Bundle(path: path),
                       let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                        title = appName
                    }
                case .windows:
                    title = URL(filePath: path).lastPathComponent
                        .replacingOccurrences(of: ".exe", with: "")
                }
            }
        }

        private func actionButtons() -> some View {
            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }

                Spacer()

                Button("Done") {
                    LocalGames.library?.insert(game)
                    isPresented = false
                }
                .disabled(path.isEmpty || title.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    GameImportView.Local(isPresented: .constant(true))
}
