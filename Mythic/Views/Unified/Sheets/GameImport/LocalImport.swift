//
//  Local.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/1/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC
import Shimmer
import UniformTypeIdentifiers
import OSLog

extension GameImportView {
    struct Local: View {
        @Binding var isPresented: Bool

        @State private var game: Game = .init(source: .local, title: .init())
        @State private var imageURLString: String = .init()
        @State private var title: String = .init()
        @State private var platform: Game.Platform = .macOS
        @State private var path: String = .init()

        @State private var isImageEmpty: Bool = true

        @State private var isGameLocationFileImporterPresented: Bool = false

        @State private var isThumbnailFileImporterPresented: Bool = false
        @State private var isThumbnailImportErrorPresented: Bool = false
        @State private var thumbnailImportError: Error?

        var body: some View {
            VStack {
                HStack {
                    if !imageURLString.isEmpty {
                        VStack {
                            GameCard.ImageCard(game: $game, isImageEmpty: $isImageEmpty)

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
                        imageURLTextField()
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
                    Text(URL(filePath: path).prettyPath())
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

        private func imageURLTextField() -> some View {
            VStack(alignment: .leading) {
                TextField(text: $imageURLString, label: {
                    Text("Enter a thumbnail URL: (optional)")

                    HStack {
                        Text("Otherwise, browse for a thumbnail file: ")

                        Button("Browse...") {
                            isThumbnailFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isThumbnailFileImporterPresented,
                            allowedContentTypes: [
                                .png, .jpeg, .gif, .bmp, .ico, .tiff, .heic, .webP
                            ]) { result in
                                switch result {
                                case .success(let url):
                                    guard url.startAccessingSecurityScopedResource() else { return }
                                    defer { url.stopAccessingSecurityScopedResource() }

                                    let thumbnailDirectoryURL: URL = Bundle.appHome!.appending(path: "Thumbnails/Custom")

                                    do {
                                        if !files.fileExists(atPath: thumbnailDirectoryURL.path(percentEncoded: false)) {
                                            try files.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)
                                        }

                                        let newThumbnailURL = thumbnailDirectoryURL.appendingPathComponent(UUID().uuidString)

                                        try files.copyItem(at: url, to: newThumbnailURL)
                                        imageURLString = newThumbnailURL.absoluteString // game.path is not stateful, so i'll have to update it as a string
                                    } catch {
                                        Logger.app.error("Unable to import thumbnail: \(error.localizedDescription)")
                                        thumbnailImportError = error
                                        isThumbnailImportErrorPresented = true
                                    }
                                case .failure(let failure):
                                    thumbnailImportError = failure
                                    isThumbnailImportErrorPresented = true
                                }
                            }
                            .alert(isPresented: $isThumbnailImportErrorPresented) {
                                Alert(
                                    title: .init("Unable to import thumbnail."),
                                    message: .init(thumbnailImportError?.localizedDescription ?? "Unknown Error."),
                                    dismissButton: .default(Text("OK"))
                                )
                            }

                    }
                })
                .truncationMode(.tail)
                .onChange(of: imageURLString) {
                    game.imageURL = URL(string: $1)
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
