//
//  GameSettings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 28/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwiftyJSON
import CachedAsyncImage

extension GameListView {
    // MARK: - SettingsView
    /// An extension of the `GameListView` that defines the `SettingsView` SwiftUI view for game settings.
    struct SettingsView: View {
        // FIXME: IN DIRE NEED OF REFACTORING THE RETINA IMPLEMENTATION
        @ObservedObject private var variables: VariableManager = .shared
        
        // MARK: - Bindings
        @Binding var isPresented: Bool
        @Binding var game: Game
        
        @State private var metadata: JSON? // FIXME: currently unused
        @State private var isFileSectionExpanded: Bool = true
        @State private var isWineSectionExpanded: Bool = true
        @State private var isDXVKSectionExpanded: Bool = true
        
        @State private var gamePath: String?
        
        @State private var bottleScope: Wine.BottleScope = .individual
        @State private var selectedBottle: String
        
        @State private var retinaMode: Bool = Wine.defaultBottleSettings.retinaMode
        @State private var modifyingRetinaMode: Bool = true
        @State private var retinaModeError: Error?
        
        init(isPresented: Binding<Bool>, game: Binding<Game>) {
            _isPresented = isPresented
            _game = game
            _selectedBottle = State(initialValue: game.wrappedValue.bottleName)
        }
        
        private func fetchRetinaStatus() async {
            modifyingRetinaMode = true
            if let bottle = Wine.allBottles?[selectedBottle] {
                await Wine.getRetinaMode(bottleURL: bottle.url) { result in
                    switch result {
                    case .success(let success):
                        retinaMode = success
                    case .failure(let failure):
                        retinaModeError = failure
                    }
                }
            }
            modifyingRetinaMode = false
        }
        
        // MARK: - Body View
        var body: some View {
            VStack {
                HStack {
                    VStack {
                        Text(game.title)
                            .font(.title)
                            .help("UUID: \(game.appName)")
                        
                        CachedAsyncImage(url: URL(
                            string: game.type == .epic
                            ? Legendary.getImage(of: game, type: .tall) 
                            : game.imageURL?.path ?? .init()
                        ), urlCache: gameImageURLCache) { phase in
                            switch phase {
                            case .empty:
                                EmptyView()
                            case .success(let image):
                                ZStack {
                                    image // FIXME: fix image stretching and try to zoom instead
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 10)) // TODO: remove corner radius on blurred image
                                        .blur(radius: 20)
                                        .frame(width: 150)
                                    
                                    image
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .modifier(FadeInModifier())
                                        .frame(width: 150)
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
                    
                    // TODO: game desc otherwise (no description available)
                    
                    // TODO: image carousel (if applicable)
                    Divider()
                    
                    HStack {
                        VStack {
                            // TODO: alternate wine
                            // TODO: !! make sure base path for games is in main settings
                        }
                        
                        GeometryReader { geometry in
                            Form {
                                Section("File", isExpanded: $isFileSectionExpanded) {
                                    HStack {
                                        Text("Move \(game.title)")
                                        
                                        Spacer()
                                        
                                        Button("Move...") { // TODO: look into whether .fileMover is a suitable alternative
                                            let openPanel = NSOpenPanel()
                                            openPanel.prompt = "Move"
                                            openPanel.canChooseDirectories = true
                                            openPanel.allowsMultipleSelection = false
                                            openPanel.canCreateDirectories = true
                                            
                                            if openPanel.runModal() == .OK {
                                                if game.type == .epic {
                                                    // game.path = openPanel.urls.first?.path ?? .init()
                                                    /* TODO: TODO
                                                     usage: cli move [-h] [--skip-move] <App Name> <New Base Path>
                                                     
                                                     positional arguments:
                                                     <App Name>       Name of the app
                                                     <New Base Path>  Directory to move game folder to
                                                     
                                                     options:
                                                     -h, --help       show this help message and exit
                                                     --skip-move      Only change legendary database, do not move files (e.g. if
                                                     already moved)
                                                     
                                                     */
                                                } else {
                                                    
                                                }
                                            }
                                        }
                                        .disabled(gamePath == nil)
                                    }
                                    HStack {
                                        VStack {
                                            HStack {
                                                Text("Game location")
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Text(URL(filePath: (gamePath ?? "[Unknown]")).prettyPath()) // FIXME: 3x repetition is bad
                                                    .foregroundStyle(.placeholder)
                                                Spacer()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button("Show in Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting(
                                                [URL(filePath: gamePath ?? .init())]
                                            )
                                        }
                                        .disabled(gamePath == nil)
                                    }
                                }
                                
                                Section("Wine", isExpanded: $isWineSectionExpanded) {
                                    BottleSettingsView(selectedBottle: $selectedBottle, withPicker: true)
                                }
                                
                                Section("DXVK", isExpanded: $isDXVKSectionExpanded) {
                                    Toggle("DXVK", isOn: Binding(get: {return .init()}, set: {_ in}))
                                        .help("Sorry, this isn't implemented yet!")
                                        .disabled(true)
                                }
                            }
                            .formStyle(.grouped)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .onAppear {
                        gamePath = game.type == .epic ? try? Legendary.getGamePath(game: game) : game.path
                    }
                    .task {
                        if game.type == .epic {
                            metadata = try? Legendary.getGameMetadata(game: game) // FIXME: currently unused
                        }
                    }
                    .task(priority: .userInitiated) { await fetchRetinaStatus() }
                    
                    .onChange(of: selectedBottle) {
                        game.bottleName = selectedBottle
                        Task(priority: .userInitiated) { await fetchRetinaStatus() }
                    }
                }
                
                Spacer()
                
                HStack {
                    /*
                     Text(game.appName)
                     .scaledToFit()
                     .foregroundStyle(.placeholder)
                     */
                    
                    Text((game.type == .epic ? try? Legendary.getGamePlatform(game: game) : game.platform)?.rawValue ?? "Unknown")
                        .padding(.horizontal, 5)
                        .overlay( // based off .buttonStyle(.accessoryBarAction)
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.tertiary)
                        )
                    
                    Text(game.type == .epic ? "Epic" : "Local")
                        .padding(.horizontal, 5)
                        .overlay( // based off .buttonStyle(.accessoryBarAction)
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.tertiary)
                        )
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "checkmark.gobackward")
                        Text("Verify")
                    }
                    .help("Not implemented")
                    .disabled(true)
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.bin")
                        Text("Uninstall")
                    }
                    .help("Not implemented")
                    .disabled(true)
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "play")
                        Text("Play")
                    }
                    .help("Not implemented")
                    .disabled(true)
                    
                    Button {
                        isPresented =  false
                    } label: {
                        Text("Close")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 600)
        }
    }
}

// MARK: - Preview
#Preview {
    GameListView.SettingsView(
        isPresented: .constant(true),
        game: .constant(.init(type: .epic, title: "Game", appName: "Test_\(UUID().uuidString)", platform: .macOS, imageURL: URL(string: "https://cdn1.epicgames.com/ut/item/ut-39a5fa32c5534e0eabede7b732ca48c8-1288x1450-9a43b56b492819d279855ae612ad85cd-1288x1450-9a43b56b492819d279855ae612ad85cd.png")))
    )
}
