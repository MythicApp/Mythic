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
import SwordRPC
import OSLog

extension LibraryView.GameImportView {
    struct Epic: View {
        @State private var installableGames: [Game] = .init()
        
        @Binding var isPresented: Bool
        
        @State private var game: Game = placeholderGame(type: .epic)
        @State private var path: String = .init()
        @State private var platform: GamePlatform = .macOS
        
        @State private var supportedPlatforms: [GamePlatform]?
        
        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true
        
        @Binding var isProgressViewSheetPresented: Bool
        @Binding var isGameListRefreshCalled: Bool
        @Binding var isErrorPresented: Bool
        @Binding var errorContent: Substring
        
        var body: some View {
            Form {
                if !installableGames.isEmpty {
                    Picker("Select a game:", selection: $game) {
                        ForEach(installableGames, id: \.self) { game in
                            Text(game.title)
                        }
                    }
                } else {
                    HStack {
                        Text("Select a game:")
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if supportedPlatforms == nil {
                    HStack {
                        Text("Choose the game's native platform:")
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Picker("Choose the game's native platform:", selection: $platform) {
                        ForEach(supportedPlatforms!, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                }
                
                HStack {
                    VStack {
                        HStack {
                            Text("Where is the game located?")
                            Spacer()
                        }
                        HStack {
                            Text(URL(filePath: path).prettyPath())
                                .foregroundStyle(.placeholder)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !files.isReadableFile(atPath: path) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .help("File/Folder is not readable by Mythic.")
                    }
                    
                    Button("Browse...") { // TODO: replace with .fileImporter
                        let openPanel = NSOpenPanel()
                        openPanel.allowedContentTypes = []
                        openPanel.canChooseDirectories = true
                        if platform == .macOS { // only way to make it update on change
                            openPanel.allowedContentTypes = [.application]
                        } else if platform == .windows {
                            openPanel.allowedContentTypes = [.exe]
                        }
                        
                        openPanel.allowsMultipleSelection = false
                        
                        if openPanel.runModal() == .OK {
                            path = openPanel.urls.first?.path ?? .init()
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
            .onChange(of: game) {
                if let fetchedPlatforms = try? Legendary.getGameMetadata(game: game)?["asset_infos"].dictionary {
                    supportedPlatforms = fetchedPlatforms.keys
                        .compactMap { key in
                            switch key {
                            case "Windows": return .windows
                            case "Mac": return .macOS
                            default: return nil
                            }
                        }
                    
                    platform = supportedPlatforms!.first!
                } else {
                    Logger.app.info("Unable to fetch supported platforms for \(game.title).")
                    supportedPlatforms = GamePlatform.allCases
                }
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
                        
                        if !game.id.isEmpty && !game.title.isEmpty {
                            command = await Legendary.command(
                                args: [
                                    "import",
                                    checkIntegrity ? nil : "--disable-check",
                                    withDLCs ? "--with-dlcs" : "--skip-dlcs",
                                    "--platform", platform == .macOS ? "Mac" : platform == .windows ? "Windows" : "Mac",
                                    game.id,
                                    path
                                ] .compactMap { $0 },
                                useCache: false,
                                identifier: "gameImport"
                            )
                        }
                        
                        if command != nil {
                            if let commandStderrString = String(data: command!.stderr, encoding: .utf8) {
                                if !commandStderrString.isEmpty {
                                    if !game.id.isEmpty && !game.title.isEmpty {
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
                .disabled(supportedPlatforms == nil)
                .buttonStyle(.borderedProminent)
            }
            
            .task(priority: .userInitiated) {
                let games = try? Legendary.getInstallable()
                guard let games = games, !games.isEmpty else { return }
                installableGames = games.filter { (try? !Legendary.getInstalledGames().contains($0)) ?? true }
                game = installableGames.first!
                isProgressViewSheetPresented = false
            }
            
            .task(priority: .background) {
                discordRPC.setPresence({
                    var presence: RichPresence = .init()
                    presence.details = "Importing & Configuring \(platform.rawValue) game \"\(game.title)\""
                    presence.state = "Importing \(game.title)"
                    presence.timestamps.start = .now
                    presence.assets.largeImage = "macos_512x512_2x"
                    
                    return presence
                }())
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
