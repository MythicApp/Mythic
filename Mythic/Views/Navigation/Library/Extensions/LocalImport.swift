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

extension LibraryView.GameImportView {
    struct Local: View {
        @Binding var isPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        
        @State private var game: Game = placeholderGame(.local)
        @State private var platform: GamePlatform = .macOS
        
        var body: some View {
            VStack {
                HStack {
                    Form {
                        TextField("What should we call this game?", text: $game.title)
                        
                        Picker("Choose the game's native platform:", selection: $platform) {
                            ForEach(type(of: platform).allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        
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
                            
                            Button("Browse...") {
                                let openPanel = NSOpenPanel()
                                openPanel.allowedContentTypes = []
                                if platform == .macOS { // only way to make it update on change
                                    openPanel.allowedContentTypes = [.application]
                                    openPanel.canChooseDirectories = false
                                } else if platform == .windows {
                                    openPanel.allowedContentTypes = [.exe]
                                    openPanel.canChooseDirectories = true
                                }
                                
                                openPanel.allowsMultipleSelection = false
                                
                                if openPanel.runModal() == .OK {
                                    game.path = openPanel.urls.first?.path ?? .init()
                                }
                            }
                        }
                        
                        TextField("Enter Thumbnail URL here... (optional)", text: Binding( // FIXME: interacting with anything else will malform the image URL for some reason
                            get: { game.imageURL?.path ?? .init() },
                            set: { game.imageURL = URL(string: $0) }
                                                                                         ))
                    }
                    .formStyle(.grouped)
                    
                    CachedAsyncImage(url: game.imageURL, urlCache: gameImageURLCache) { phase in
                        switch phase {
                        case .empty:
                            EmptyView()
                        case .success(let image):
                            HStack {
                                Divider()
                                    .padding()
                                
                                ZStack {
                                    image // fix image stretching and try to zoom instead
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .blur(radius: 20)
                                        .frame(width: 150)
                                    
                                    image
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .modifier(FadeInModifier())
                                        .frame(width: 150)
                                }
                            }
                            .scaledToFit()
                        case .failure:
                            Image(systemName: "network.slash")
                                .symbolEffect(.appear)
                                .imageScale(.large)
                        @unknown default:
                            Image(systemName: "exclamationmark.triangle")
                                .symbolEffect(.appear)
                                .imageScale(.large)
                        }
                    }
                }
                
                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        LocalGames.library? += [game]
                        isPresented = false
                        isGameListRefreshCalled = true
                    }
                    .disabled(game.path?.isEmpty ?? false)
                    .disabled(game.title.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                
                .task(priority: .high) {
                    game.path = .init() // IMPORTANT, OR DONE BUTTON WILL NOT DISABLE PROPERLY
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
