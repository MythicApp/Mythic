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

// FIXME: refactor: warning ‼️ below code may need a cleanup
extension GameImportView {
    struct Local: View {
        @Binding var isPresented: Bool

        @State private var game: Game = placeholderGame(forSource: .local)
        @State private var imageURLString: String = .init()
        @State private var title: String = .init()
        @State private var platform: Game.Platform = .macOS
        @State private var location: URL?

        @State private var isImageEmpty: Bool = true
        @State private var imageRefreshFlag: Bool = false

        @State private var isGameLocationFileImporterPresented: Bool = false

        private func updateGameTitle() {
            if let location = location, title.isEmpty {
                switch platform {
                case .macOS:
                    if let bundle = Bundle(path: location.path),
                       let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                        title = bundleName
                    }
                case .windows:
                    title = location.lastPathComponent
                        .replacingOccurrences(of: ".exe", with: "")
                }
            }
        }

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
                        TextField("What should we call this game?", text: $title)
                            .onChange(of: title) { game.title = $1 }

                        Picker("Choose the game's native platform:", selection: $platform) {
                            ForEach(Game.Platform.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .task { game.platform = platform }
                        .onChange(of: platform) {
                            game.platform = $1
                            title = .init()
                            location = nil
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Choose the game's install location:")
                                if let location = location {
                                    Text(location.prettyPath)
                                        .foregroundStyle(.placeholder)
                                }
                            }

                            if let location = location,
                               !files.isReadableFile(atPath: location.path) {
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
                        .onChange(of: location) { _, newValue in
                            updateGameTitle()
                            game.location = newValue
                        }

                        GameCard.ImageURLModifierView(game: $game, imageURLString: $imageURLString)
                            .onChange(of: imageURLString, { imageRefreshFlag.toggle() })
                    }
                    .formStyle(.grouped)
                }

                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }

                    Spacer()

                    Button("Done") {
                        LocalGames.library?.insert(game)
                        isPresented = false
                    }
                    .disabled(location == nil)
                    .disabled(title.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                    .padding()
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
    }
}

#Preview {
    GameImportView.Local(isPresented: .constant(true))
}
