//
//  AddGameView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

extension LibraryView {
    struct ImportGameView: View {
        @Binding var isPresented: Bool
        @State private var isProgressViewSheetPresented: Bool = false
        
        @State private var installableGames: [String] = []
        
        @State private var selectedGame: String = "" // is initialised onappear
        @State private var selectedGameType: String = "Epic"
        @State private var selectedPlatform: String = "macOS"
        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true
        
        
        @State private var gamePath: String = ""
        
        var body: some View {
            VStack {
                Text("Import a Game")
                    .font(.title)
                    .multilineTextAlignment(.leading)
                
                Divider()
                
                Picker("", selection: $selectedGameType) {
                    ForEach(["Epic", "Local"], id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)
                
                if selectedGameType == "Epic" {
                    Picker("Select a game:", selection: $selectedGame) {
                        ForEach(installableGames, id: \.self) {
                            Text($0)
                        }
                    }
                    
                    HStack {
                        TextField("Enter game path or click \"Browse...\"", text: $gamePath)
                            .frame(width: 300)
                        
                        Button("Browse...") {
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [.exe, .application]
                            openPanel.canChooseDirectories = true
                            openPanel.allowsMultipleSelection = false
                            
                            if openPanel.runModal() == .OK {
                                gamePath = openPanel.urls.first!.path
                            }
                        }
                    }
                    
                    Picker("Choose the game's native platform:", selection: $selectedPlatform) {
                        ForEach(["macOS", "Windows"], id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Toggle(isOn: $withDLCs) {
                            Text("Import with DLCs")
                        }
                        // .toggleStyle(.switch)
                        Spacer()
                    }
                    
                    HStack {
                        Toggle(isOn: $checkIntegrity) {
                            Text("Verify the game's integrity")
                        }
                        // .toggleStyle(.switch)
                        Spacer()
                    }
                    
                } else if selectedGameType == "Local" {
                    Image(systemName: "pencil.and.scribble")
                        .symbolEffect(.pulse)
                        .imageScale(.large)
                        .padding()
                }
                
                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented.toggle()
                    }
                    
                    Spacer()
                    
                    Button("Done", role: .none) {
                        isPresented.toggle()
                        var realSelectedPlatform = selectedPlatform
                        
                        if selectedPlatform == "macOS" {
                            realSelectedPlatform = "Mac"
                        }
                        
                        _ = Legendary.command(
                            args: [
                                "import",
                                checkIntegrity ? nil : "--disable-check",
                                withDLCs ? "--with-dlcs" : "--skip-dlcs",
                                "--platform", realSelectedPlatform,
                                selectedGame,
                                gamePath
                            ]
                                .compactMap { $0 }
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.global().async {
                    let games = LegendaryJson.getInstallable()
                    DispatchQueue.main.async { [self] in
                        selectedGame = games.appTitles.first ?? "Error retrieving game list"
                        installableGames = games.appTitles
                        isProgressViewSheetPresented = false
                    }
                }
            }
            .padding()
        }
    }
}


#Preview {
    LibraryView()
}
