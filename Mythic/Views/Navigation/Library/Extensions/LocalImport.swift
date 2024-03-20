//
//  Local.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/1/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import CachedAsyncImage
import SwordRPC

extension LibraryView.GameImportView {
    struct Local: View {
        @Binding var isPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        
        @State private var game: Game = placeholderGame(type: .local)
        @State private var platform: GamePlatform = .macOS
        
        private func updateGameTitle() {
            if let path = game.path, !path.isEmpty, game.title.isEmpty {
                switch platform {
                case .macOS:
                    if let bundle = Bundle(path: path),
                        let selectedAppName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                        game.title = selectedAppName // not to be confused with game.id
                    }
                case .windows:
                    game.title = URL(filePath: path).lastPathComponent.replacingOccurrences(of: ".exe", with: "") // add support for other
                }
            }
        }
        
        var body: some View {
            VStack {
                HStack {
                    if game.imageURL != nil {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.background)
                            .aspectRatio(3/4, contentMode: .fit)
                            .overlay { // MARK: Image
                                CachedAsyncImage(url: game.imageURL) { phase in
                                    switch phase {
                                    case .empty:
                                        if case .local = game.type {
                                            let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))
                                            
                                            image
                                                .resizable()
                                                .aspectRatio(3/4, contentMode: .fill)
                                                .blur(radius: 20.0)
                                            
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .modifier(FadeInModifier())
                                        } else {
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(.windowBackground)
                                                .shimmering(
                                                    animation: .easeInOut(duration: 1)
                                                        .repeatForever(autoreverses: false),
                                                    bandSize: 1
                                                )
                                        }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(3/4, contentMode: .fill)
                                            .clipShape(.rect(cornerRadius: 20))
                                            .blur(radius: 10.0)
                                        
                                        image
                                            .resizable()
                                            .aspectRatio(3/4, contentMode: .fill)
                                            .clipShape(.rect(cornerRadius: 20))
                                            .modifier(FadeInModifier())
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.windowBackground)
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.windowBackground)
                                    }
                                }
                            }
                    }
                    
                    Form {
                        TextField("What should we call this game?", text: $game.title)
                        
                        Picker("Choose the game's native platform:", selection: $platform) {
                            ForEach(type(of: platform).allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .onChange(of: platform) {
                            game.platform = $1
                            game.title = .init()
                            game.path = .init()
                        }
                        .task { game.platform = platform }
                        
                        HStack {
                            VStack {
                                HStack { // FIXME: jank
                                    Text("Where is the game located?")
                                    Spacer()
                                }
                                HStack {
                                    Text(URL(filePath: game.path ?? .init()).prettyPath())
                                        .foregroundStyle(.placeholder)
                                    
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                            
                            if !files.isReadableFile(atPath: game.path ?? .init()) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .help("File/Folder is not readable by Mythic.")
                            }
                            
                            // TODO: unify
                            Button("Browse...") { // TODO: replace with .fileImporter
                                let openPanel = NSOpenPanel()
                                openPanel.allowedContentTypes = []
                                openPanel.canChooseDirectories = true
                                if platform == .macOS { // only way to make it update on change, no switch
                                    openPanel.allowedContentTypes = [.application]
                                } else if platform == .windows {
                                    openPanel.allowedContentTypes = [.exe]
                                }
                                
                                openPanel.allowsMultipleSelection = false
                                
                                if openPanel.runModal() == .OK {
                                    game.path = openPanel.urls.first?.path ?? .init()
                                }
                            }
                        }
                        
                        .onChange(of: game.path) { updateGameTitle() }
                        
                        TextField(
                            "Enter Thumbnail URL here... (optional)",
                            text: Binding(
                                get: { game.imageURL?.absoluteString ?? .init() },
                                set: { game.imageURL = .init(string: $0) }
                                         )
                        )
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
                        isGameListRefreshCalled = true
                    }
                    .disabled(game.path?.isEmpty ?? false)
                    .disabled(game.title.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                
                .task(priority: .high) {
                    game.path = .init()
                }
                
                .task(priority: .background) { // TODO: same as in epicimport, can be unified?
                    discordRPC.setPresence({
                        var presence: RichPresence = .init()
                        presence.details = "Importing & Configuring \(platform.rawValue) game \"\(game.title)\""
                        presence.state = "Importing \(game.title)"
                        presence.timestamps.start = .now
                        presence.assets.largeImage = "macos_512x512_2x"
                        
                        return presence
                    }())
                }
            }
        }
    }
}

#Preview {
    LibraryView.GameImportView.Local(
        isPresented: .constant(true),
        isGameListRefreshCalled: .constant(false)
    )
}
