//
//  Local.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/1/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import CachedAsyncImage
import SwordRPC
import Shimmer
import UniformTypeIdentifiers

extension GameImportView {
    struct Local: View {
        @Binding var isPresented: Bool

        @State private var game: Game = .init(source: .local, title: .init())
        @State private var imageURLString: String = .init()
        @State private var title: String = .init()
        @State private var platform: Game.Platform = .macOS
        @State private var path: String = .init()

        var body: some View {
            VStack {
                HStack {
                    if !imageURLString.isEmpty {
                        VStack {
                            GameCard.ImageCard(game: $game)

                            Label("Images with a 3:4 aspect ratio fit the best.", systemImage: "info.circle")
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
                .onChange(of: title) { game.title = $0 }
        }

        private func platformPicker() -> some View {
            Picker("Choose the game's native platform:", selection: $platform) {
                ForEach(Game.Platform.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .onChange(of: platform) {
                game.platform = $0
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
                    Text("Where is the game located?")
                    Text(URL(filePath: path).prettyPath())
                        .foregroundStyle(.placeholder)
                }

                if !files.isReadableFile(atPath: path), !path.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .help("File/Folder is not readable by Mythic.")
                }

                Spacer()

                Button("Browse...") {
                    openFileBrowser()
                }
            }
            .onChange(of: path) {
                updateGameTitle()
                game.path = $0
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

        private func openFileBrowser() {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = false
            openPanel.allowedContentTypes = allowedContentTypes(for: platform)
            openPanel.allowsMultipleSelection = false

            if openPanel.runModal() == .OK {
                path = openPanel.urls.first?.path ?? .init()
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

        private func imageURLTextField() -> some View {
            TextField("Enter Thumbnail URL here... (optional)", text: $imageURLString)
                .truncationMode(.tail)
                .onChange(of: imageURLString) {
                    game.imageURL = URL(string: $0)
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
