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
            HStack {
                VStack {
                    HStack {
                        Text("Game title:")
                        TextField("What should we call this game?", text: $game.title)
                    }
                    
                    Picker("Choose the game's native platform:", selection: $platform) {
                        ForEach(type(of: platform).allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        TextField("Enter game path or click \"Browse…\"", text: Binding(
                            get: { game.path ?? .init() },
                            set: { game.path = $0 }
                        )) // TODO: if game path invalid, disable done and add warning icon with tooltip
                        
                        Button("Browse…") {
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [
                                game.platform == .macOS ? .exe : nil,
                                game.platform == .windows ? .application : nil
                            ]
                                .compactMap { $0 }
                            openPanel.canChooseDirectories = game.platform == .macOS // FIXME: Legendary (presumably) handles dirs (check this in case it doesnt)
                            openPanel.allowsMultipleSelection = false
                            
                            if openPanel.runModal() == .OK {
                                game.path = openPanel.urls.first?.path ?? .init()
                            }
                        }
                    }
                    
                    HStack {
                        Text("Thumbnail URL (optional)")
                        TextField("Enter URL here.", text: Binding(
                            get: {
                                game.imageURL?.path ?? .init()
                            }, set: {
                                game.imageURL = URL(string: $0)
                            }
                        ))
                    }
                }
                
                CachedAsyncImage(
                    url: URL(string: game.imageURL?.path ?? .init()),
                    urlCache: URLCache(memoryCapacity: 128_000_000, diskCapacity: 768_000_000) // in bytes
                ) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        ZStack {
                            image
                                .resizable()
                                .aspectRatio(3/4, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .blur(radius: 20)
                            
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .aspectRatio(3/4, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .modifier(FadeInModifier())
                        }
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
            
            .onAppear {
                game.path = .init() // IMPORTANT, OR DONE BUTTON WILL NOT DISABLE PROPERLY
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
