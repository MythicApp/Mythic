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

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import OSLog

extension LibraryView {
    
    // MARK: - GameImportView Struct
    struct GameImportView: View {
        
        // MARK: - Binding Variables
        @Binding var isPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        
        // MARK: - State Variables
        @State private var isProgressViewSheetPresented: Bool = false
        @State private var isErrorPresented: Bool = false
        @State private var errorContent: Substring = .init()
        
        @State private var installableGames: [Legendary.Game] = .init()
        @State private var selectedGame: Legendary.Game = Legendary.placeholderGame
        @State private var selectedGameType: GameType = .epic
        @State private var selectedPlatform: GamePlatform = .macOS
        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true
        @State private var gamePath: String = .init()
        
        @State private var localGameTitle: String = .init()
        @State private var localGamePath: String = .init()
        @State private var localSelectedGameType: GameType = .epic
        @State private var localSelectedPlatform: GamePlatform = .macOS
        
        // MARK: - Body
        var body: some View { // TODO: split up epic and local into different view files
            VStack {
                Text("Import a Game")
                    .font(.title)
                    .multilineTextAlignment(.leading)
                
                Divider()
                
                Picker(String(), selection: $selectedGameType) {
                    ForEach(type(of: selectedGameType).allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                if selectedGameType == .epic {
                    Picker("Select a game:", selection: $selectedGame) {
                        ForEach(installableGames, id: \.self) { game in
                            Text(game.title)
                        }
                    }
                    
                    Picker("Choose the game's native platform:", selection: $selectedPlatform) {
                        ForEach(type(of: selectedPlatform).allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        TextField("Enter game path or click \"Browse…\"", text: $gamePath) // TODO: if game path invalid, disable done and add warning icon with tooltip
                        
                        Button("Browse…") {
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [
                                selectedPlatform == .windows ? .exe : nil,
                                selectedPlatform == .macOS ? .application : nil
                            ]
                                .compactMap { $0 }
                            openPanel.canChooseDirectories = selectedPlatform == .windows ? true : false // FIXME: Legendary (presumably) handles dirs (check this in case it doesnt)
                            openPanel.allowsMultipleSelection = false
                            
                            if openPanel.runModal() == .OK {
                                gamePath = openPanel.urls.first!.path
                            }
                        }
                    }
                    
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
                            isProgressViewSheetPresented = true
                            
                            Task(priority: .userInitiated) {
                                var command: (stdout: Data, stderr: Data)?
                                
                                if !selectedGame.appName.isEmpty && !selectedGame.title.isEmpty {
                                    command = await Legendary.command(
                                        args: [
                                            "import",
                                            checkIntegrity ? nil : "--disable-check",
                                            withDLCs ? "--with-dlcs" : "--skip-dlcs",
                                            "--platform", selectedPlatform == .macOS ? "Mac" : selectedPlatform == .windows ? "Windows" : "Mac",
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
                    
                } else if selectedGameType == .local {
                    HStack {
                        Text("Game title:")
                        TextField("What should we call this game?", text: $localGameTitle)
                    }
                    
                    Picker("Choose the game's native platform:", selection: $localSelectedPlatform) {
                        ForEach(type(of: localSelectedPlatform).allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        TextField("Enter game path or click \"Browse…\"", text: $localGamePath) // TODO: if game path invalid, disable done and add warning icon with tooltip
                        
                        Button("Browse…") {
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [
                                localSelectedPlatform == .windows ? .exe : nil,
                                localSelectedPlatform == .macOS ? .application : nil
                            ]
                                .compactMap { $0 }
                            openPanel.canChooseDirectories = localSelectedPlatform == .windows ? true : false // FIXME: Legendary (presumably) handles dirs (check this in case it doesnt)
                            openPanel.allowsMultipleSelection = false
                            
                            if openPanel.runModal() == .OK {
                                localGamePath = openPanel.urls.first!.path
                            }
                        }
                    }
                    
                    HStack {
                        Button("Cancel", role: .cancel) {
                            isPresented = false
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            var localGameLibrary: [LocalGames.Game] { // FIXME: is there a way to init it at the top
                                get {
                                    return (try? PropertyListDecoder().decode(
                                        Array.self,
                                        from: defaults.object(forKey: "localGameLibrary") as? Data ?? Data()
                                    )) ?? .init() // FIXME: do-catch goes here so local games arent randomly wiped
                                }
                                set {
                                    do {
                                        defaults.set(
                                            try PropertyListEncoder().encode(newValue),
                                            forKey: "localGameLibrary"
                                        )
                                    } catch {
                                        Logger.app.error("Unable to retrieve local game library: \(error)")
                                    }
                                }
                            }
                            
                            localGameLibrary.append(.init(
                                title: localGameTitle,
                                platform: localSelectedPlatform,
                                path: localGamePath
                            ))
                            
                            isGameListRefreshCalled = true
                        }
                        .disabled(localGamePath.isEmpty)
                        .disabled(localGameTitle.isEmpty)
                        .buttonStyle(.borderedProminent)
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
