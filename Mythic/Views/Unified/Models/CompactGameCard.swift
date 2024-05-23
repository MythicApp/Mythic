//
//  CompactGameCard.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 19/5/2024.
//

import SwiftUI
import CachedAsyncImage

struct CompactGameCard: View {
    @Binding var game: Game
    
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject private var operation: GameOperation = .shared
    @AppStorage("minimiseOnGameLaunch") private var minimizeOnGameLaunch: Bool = false
    
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
                        if case .local = game.type, game.imageURL == nil {
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
                                        switch game.type {
                                        case .epic:
                                            try await Legendary.launch(
                                                game: game,
                                                online: networkMonitor.isEpicAccessible
                                            )
                                        case .local:
                                            try await LocalGames.launch(game: game)
                                        }
                                        
                                        if minimizeOnGameLaunch { NSApp.windows.first?.miniaturize(nil) }
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
                        .padding()
                }
            }
    }
}

#Preview {
    CompactGameCard(game: .constant(.init(type: .epic, title: "firtbite;", wideImageURL: .init(string: "https://i.imgur.com/CZt2F4s.png"))))
        .padding()
}
