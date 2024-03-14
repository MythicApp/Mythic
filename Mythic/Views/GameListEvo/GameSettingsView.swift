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
                    .fill(.background)
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay { // MARK: Image
                        CachedAsyncImage(url: game.imageURL) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.windowBackground)
                                    .shimmering(
                                        animation: .easeInOut(duration: 1)
                                            .repeatForever(autoreverses: false),
                                        bandSize: 1
                                    )
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
                                    .fill(.windowBackground)
                            @unknown default:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.windowBackground)
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
                        
                        Button("Move...") { // TODO: look into whether .fileMover is a suitable alternative
                            let openPanel = NSOpenPanel()
                            openPanel.prompt = "Move"
                            openPanel.canChooseDirectories = true
                            openPanel.allowsMultipleSelection = false
                            openPanel.canCreateDirectories = true
                            
                            switch game.type {
                            case .epic:
                                openPanel.directoryURL = .init(filePath: (try? Legendary.getGamePath(game: game)) ?? .init())
                            case .local:
                                openPanel.directoryURL = .init(filePath: game.path ?? .init())
                            }
                            
                            if case .OK = openPanel.runModal(), let newLocation = openPanel.urls.first {
                                Task.sync { // FIXME: can lock main, replace with async and progressview
                                    do {
                                        try await game.move(to: newLocation)
                                    } catch {
                                        movingError = error
                                        isMovingErrorPresented = true
                                    }
                                }
                            }
                        }
                        .alert(isPresented: $isMovingErrorPresented) {
                            Alert(
                                title: .init("Unable to move \"\(game.title)\"."),
                                message: .init(movingError?.localizedDescription ?? "Unknown Error.")
                            )
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
                .onChange(of: selectedBottle) { game.bottleName = $1 }
            }
            .formStyle(.grouped)
        }
        
        HStack {
            Text(game.platform?.rawValue ?? "Unknown")
                .padding(.horizontal, 5)
                .overlay( // based off .buttonStyle(.accessoryBarAction)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.tertiary)
                )
            
            Text(game.type.rawValue)
                .padding(.horizontal, 5)
                .overlay( // based off .buttonStyle(.accessoryBarAction)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.tertiary)
                )
            
            if let recent = try? PropertyListDecoder().decode(Game.self, from: defaults.object(forKey: "recentlyPlayed") as? Data ?? .init()),
               recent == game {
                Text("Recent")
                    .padding(.horizontal, 5)
                    .overlay( // based off .buttonStyle(.accessoryBarAction)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.tertiary)
                    )
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
    GameSettingsView(game: .constant(placeholderGame(type: .epic)), isPresented: .constant(true))
}
