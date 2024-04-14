//
//  GameSettingsView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/3/2024.
//

import SwiftUI
import CachedAsyncImage
import Shimmer
import SwordRPC

struct GameSettingsView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool
    
    @State private var selectedBottle: String
    
    init(game: Binding<Game>, isPresented: Binding<Bool>) {
        _game = game
        _isPresented = isPresented
        _selectedBottle = State(initialValue: game.wrappedValue.bottleName)
    }
    
    @State private var moving: Bool = false
    @State private var movingError: Error?
    @State private var isMovingErrorPresented: Bool = false
    
    @State private var isFileSectionExpanded: Bool = true
    @State private var isWineSectionExpanded: Bool = true
    
    var body: some View {
        HStack {
            VStack {
                Text(game.title)
                    .font(.title)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(.windowBackground)
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay { // MARK: Image
                        CachedAsyncImage(url: game.imageURL) { phase in
                            switch phase {
                            case .empty:
                                if case .local = game.type, game.imageURL == nil {
                                    let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))
                                    
                                    image
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fill)
                                        .blur(radius: 20.0)
                                    
                                    image
                                        .resizable()
                                        .scaledToFit()
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
                                // fallthrough
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.background)
                                    .overlay {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                    }
                            @unknown default:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.background)
                                    .overlay {
                                        Image(systemName: "questionmark.circle.fill")
                                    }
                            }
                        }
                    }
            }
            .padding(.trailing)
            
            Divider()
            
            Form {
                Section("File", isExpanded: $isFileSectionExpanded) {
                    HStack {
                        Text("Move \"\(game.title)\"")
                        
                        Spacer()
                        
                        if !moving {
                            Button("Move...") { // TODO: look into whether .fileMover is a suitable alternative
                                let openPanel = NSOpenPanel()
                                openPanel.prompt = "Move"
                                openPanel.canChooseDirectories = true
                                openPanel.allowsMultipleSelection = false
                                openPanel.canCreateDirectories = true
                                openPanel.directoryURL = .init(filePath: game.path ?? .init())
                                
                                if case .OK = openPanel.runModal(), let newLocation = openPanel.urls.first {
                                    Task.sync { // FIXME: can lock main, replace with async and progressview
                                        do {
                                            moving = true
                                            try await game.move(to: newLocation)
                                            moving = false
                                        } catch {
                                            movingError = error
                                            isMovingErrorPresented = true
                                        }
                                    }
                                }
                            }
                            .disabled(GameOperation.shared.runningGames.contains(game))
                            .alert(isPresented: $isMovingErrorPresented) {
                                Alert(
                                    title: .init("Unable to move \"\(game.title)\"."),
                                    message: .init(movingError?.localizedDescription ?? "Unknown Error.")
                                )
                            }
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    
                    HStack {
                        VStack {
                            HStack {
                                Text("Game Location:")
                                Spacer()
                            }
                            
                            HStack {
                                Text(URL(filePath: game.path ?? "Unknown").prettyPath())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        
                        Spacer()
                        
                        Button("Show in Finder") {
                            workspace.activateFileViewerSelecting([URL(filePath: game.path!)])
                        }
                        .disabled(game.path == nil)
                    }
                }
                
                Section("Wine", isExpanded: $isWineSectionExpanded) {
                    BottleSettingsView(selectedBottle: $selectedBottle, withPicker: true)
                }
                .disabled(game.platform != .windows)
                .disabled(!Libraries.isInstalled())
                .onChange(of: selectedBottle) { game.bottleName = $1 }
            }
            .formStyle(.grouped)
        }
        
        HStack {
            SubscriptedTextView(game.platform?.rawValue ?? "Unknown")
            
            SubscriptedTextView(game.type.rawValue)
            
            if (try? PropertyListDecoder().decode(Game.self, from: defaults.object(forKey: "recentlyPlayed") as? Data ?? .init())) == game {
                SubscriptedTextView("Recent")
            }
            
            Spacer()
            
            Button {
                isPresented =  false
            } label: {
                Text("Close")
            }
            .buttonStyle(.borderedProminent)
        }
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Configuring \(game.platform?.rawValue ?? .init()) game \"\(game.title)\""
                presence.state = "Configuring \(game.title)"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
    }
}

#Preview {
    GameSettingsView(game: .constant(.init(type: .epic, title: .init())), isPresented: .constant(true))
}
