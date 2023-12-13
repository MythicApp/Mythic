//
//  AddGameView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI

extension LibraryView {
    
    // MARK: - GameImportView Struct
    struct GameImportView: View {
        
        // MARK: - Binding Variables
        @Binding var isPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        
        // MARK: - State Variables
        @State private var isProgressViewSheetPresented: Bool = false
        @State private var isErrorPresented: Bool = false
        @State private var errorContent: Substring = Substring()
        
        @State private var installableGames: [Legendary.Game] = Array()
        @State private var selectedGame: Legendary.Game = .init(appName: String(), title: String())
        @State private var selectedGameType: String = "Epic"
        @State private var selectedPlatform: String = "macOS"
        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true
        @State private var gamePath: String = String()
        
        // MARK: - Body
        var body: some View {
            VStack {
                Text("Import a Game")
                    .font(.title)
                    .multilineTextAlignment(.leading)
                
                Divider()
                
                Picker(String(), selection: $selectedGameType) {
                    ForEach(["Epic", "Local"], id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)
                
                if selectedGameType == "Epic" {
                    Picker("Select a game:", selection: $selectedGame) {
                        ForEach(installableGames, id: \.self) { game in
                            Text(game.title)
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
                        Spacer()
                    }
                    
                    HStack {
                        Toggle(isOn: $checkIntegrity) {
                            Text("Verify the game's integrity")
                        }
                        Spacer()
                    }
                    
                    HStack {
                        Button("Cancel", role: .cancel) {
                            isPresented = false
                        }
                        
                        Spacer()
                        
                        Button("Done", role: .none) {
                            var realSelectedPlatform = selectedPlatform
                            if selectedPlatform == "macOS" {
                                realSelectedPlatform = "Mac"
                            }
                            
                            isProgressViewSheetPresented = true
                            
                            Task(priority: .userInitiated) {
                                var command: (stdout: Data, stderr: Data)?
                                
                                if !selectedGame.appName.isEmpty && !selectedGame.title.isEmpty {
                                    command = await Legendary.command(
                                        args: [
                                            "import",
                                            checkIntegrity ? nil : "--disable-check",
                                            withDLCs ? "--with-dlcs" : "--skip-dlcs",
                                            "--platform", realSelectedPlatform,
                                            selectedGame.appName,
                                            gamePath
                                        ]
                                        .compactMap { $0 },
                                        useCache: false,
                                        identifier: "gameImport"
                                    )
                                }
                                
                                if command != nil {
                                    if let commandStderrString = String(data: command!.stderr, encoding: .utf8) {
                                        if !commandStderrString.isEmpty {
                                            if !selectedGame.appName.isEmpty && !selectedGame.title.isEmpty {
                                                if commandStderrString.contains("INFO: Game \"\(selectedGame.title)\" has been imported.") {
                                                    isPresented = false
                                                    isGameListRefreshCalled = true
                                                }
                                            }
                                        }
                                        
                                        for line in commandStderrString.components(separatedBy: "\n") {
                                            if line.contains("ERROR:") {
                                                if let range = line.range(of: "ERROR: ") {
                                                    let substring = line[range.upperBound...]
                                                    errorContent = substring
                                                    isProgressViewSheetPresented = false
                                                    isErrorPresented = true
                                                    break // first err
                                                }
                                            }
                                            
                                            // legendary/cli.py line 1372 as of hash 4507842
                                            if line.contains(
                                                "Some files are missing from the game installation, install may not"
                                                + " match latest Epic Games Store version or might be corrupted."
                                            ) {
                                                // TODO: implement
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .disabled(gamePath.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    
                } else if selectedGameType == "Local" {
                    Image(systemName: "pencil.and.scribble")
                        .symbolEffect(.pulse)
                        .imageScale(.large)
                        .padding()
                    
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }
                }
            }
            
            .padding()
            
            .onAppear {
                Task(priority: .userInitiated) {
                    let games = try? await Legendary.getInstallable()
                    if let games = games, !games.isEmpty { selectedGame = games.first! }
                    installableGames = games ?? installableGames
                    isProgressViewSheetPresented = false
                }
            }
            
            .sheet(isPresented: $isProgressViewSheetPresented) {
                ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
            }
            
            .alert(isPresented: $isErrorPresented) {
                Alert(
                    title: Text("Error importing game"),
                    message: Text(errorContent)
                )
            }
        }
    }
}

#Preview {
    LibraryView.GameImportView(
        isPresented: .constant(true),
        isGameListRefreshCalled: .constant(false)
    )
}
