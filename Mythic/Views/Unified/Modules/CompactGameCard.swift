//
//  CompactGameCard.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 19/5/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import CachedAsyncImage

struct CompactGameCard: View {
    @Binding var game: Game
    
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject private var operation: GameOperation = .shared
    @ObservedObject private var data = DatabaseData.shared
    
    @State private var isLaunchErrorAlertPresented: Bool = false
    @State private var launchError: Error?
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .aspectRatio(1, contentMode: .fit)
            .overlay { // MARK: Image
                CachedAsyncImage(url: game.wideImageURL ?? game.imageURL) { phase in
                    switch phase {
                    case .empty:
                        if case .local = game.source, game.imageURL == nil {
                            let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))
                            
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .blur(radius: 20.0)
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
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(.rect(cornerRadius: 20))
                            .blur(radius: 20.0)
                            .modifier(FadeInModifier())
                    case .failure:
                        // fallthrough
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                    @unknown default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.windowBackground)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack {
                    // MARK: Game Title Stack
                    HStack {
                        Text(game.title)
                            .font(.bold(.title3)())
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // ! Changes made here must also be reflected in GameCard's play button
                        if operation.launching == game {
                            ProgressView()
                                .controlSize(.small)
                                .padding(5)
                                .clipShape(.circle)
                            
                        } else {
                            Button {
                                Task(priority: .userInitiated) {
                                    do {
                                        switch game.source {
                                        case .epic:
                                            try await Legendary.launch(game: game)
                                        case .local:
                                            try await LocalGames.launch(game: game)
                                        }
                                        
                                        if data.data.hideMythicOnGameLaunch { NSApp.windows.first?.miniaturize(nil) }
                                    } catch {
                                        launchError = error
                                        isLaunchErrorAlertPresented = true
                                    }
                                }
                            } label: {
                                Image(systemName: "play")
                                    .padding(5)
                            }
                            .clipShape(.circle)
                            .help(game.path != nil ? "Play \"\(game.title)\"" : "Unable to locate \(game.title) at its specified path (\(game.path ?? "Unknown"))")
                            .disabled(game.path != nil ? !files.fileExists(atPath: game.path!) : false)
                            .disabled(operation.runningGames.contains(game))
                            .disabled(Wine.bottleURLs.isEmpty)
                            .alert(isPresented: $isLaunchErrorAlertPresented) {
                                Alert(
                                    title: .init("Error launching \"\(game.title)\"."),
                                    message: .init(launchError?.localizedDescription ?? "Unknown Error.")
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                .scaledToFit()
            }
            .overlay(alignment: .topLeading) {
                if game.isFavourited {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.white)
                        .padding()
                }
            }
    }
}

#Preview {
    CompactGameCard(game: .constant(.init(source: .epic, title: "test", wideImageURL: .init(string: "https://i.imgur.com/CZt2F4s.png"))))
        .padding()
}
