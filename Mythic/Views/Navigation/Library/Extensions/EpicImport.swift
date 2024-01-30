//
//  Epic.swift
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

extension LibraryView.GameImportView {
    struct Epic: View {
        @State private var installableGames: [Game] = .init()
        
        @Binding var isPresented: Bool
        
        @State private var game: Game = placeholderGame(.epic)
        @State private var path: String = .init()
        @State private var platform: GamePlatform = .macOS
        
        @State private var withDLCs: Bool = false
        @State private var checkIntegrity: Bool = false
        
        @Binding var isProgressViewSheetPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        @Binding var isErrorPresented: Bool
        @Binding var errorContent: Substring
        
        var body: some View {
            Form {
                Picker("Select a game:", selection: $game) {
                    ForEach(installableGames, id: \.self) { game in
                        Text(game.title)
                    }
                }
                
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
                    
                    if !FileLocations.isWritableFolder(url: URL(filePath: game.path ?? .init())) ||
                        !files.isWritableFile(atPath: game.path ?? .init()) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .help("Folder is not writable.")
                    }
                    
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
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Done", role: .none) {
                    isProgressViewSheetPresented = true
                    
                    Task(priority: .userInitiated) {
                        var command: (stdout: Data, stderr: Data)?
                        
                        if !game.appName.isEmpty && !game.title.isEmpty { // FIXME: appName force-unwrap hurts, alternative??
                            command = await Legendary.command(
                                args: [
                                    "import",
                                    checkIntegrity ? nil : "--disable-check",
                                    withDLCs ? "--with-dlcs" : "--skip-dlcs",
                                    "--platform", platform == .macOS ? "Mac" : platform == .windows ? "Windows" : "Mac",
                                    game.appName,
                                    path
                                ]
                                    .compactMap { $0 },
                                useCache: false,
                                identifier: "gameImport"
                            )
                        }
                        
                        if command != nil {
                            if let commandStderrString = String(data: command!.stderr, encoding: .utf8) {
                                if !commandStderrString.isEmpty {
                                    if !game.appName.isEmpty && !game.title.isEmpty {
                                        if commandStderrString.contains("INFO: Game \"\(game.title)\" has been imported.") {
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
                .disabled(path.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            
            .task(priority: .userInitiated) {
                let games = try? await Legendary.getInstallable()
                if let games = games, !games.isEmpty { game = games.first! }
                installableGames = games ?? installableGames
                isProgressViewSheetPresented = false
            }
        }
    }
}

#Preview {
    LibraryView.GameImportView.Epic(
        isPresented: .constant(true),
        isProgressViewSheetPresented: .constant(false),
        isGameListRefreshCalled: .constant(false),
        isErrorPresented: .constant(false),
        errorContent: .constant(.init())
    )
}
