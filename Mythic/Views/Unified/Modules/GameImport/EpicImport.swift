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

extension GameImportView {
    struct Epic: View {
        @Binding var isPresented: Bool
        @State private var errorDescription: String = .init()
        @State private var isErrorAlertPresented = false
        
        @State private var installableGames: [Game] = .init()
        @State private var game: Game = .init(source: .epic, title: .init())
        @State private var path: String = .init()
        @State private var platform: Game.Platform = .macOS
        
        @State private var supportedPlatforms: [Game.Platform]?
        
        @State private var withDLCs: Bool = true
        @State private var checkIntegrity: Bool = true
        
        @State private var isOperating: Bool = false
        
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
                    
                    if let platform = supportedPlatforms?.first {
                        self.platform = platform
                    }
                } else {
                    Logger.app.info("Unable to fetch supported platforms for \(game.title).")
                    supportedPlatforms = Game.Platform.allCases
                }
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                
                Spacer()
                
                if isOperating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(0.5)
                }
                
                Button("Done", role: .none) {
                    isOperating = true
                    
                    Task(priority: .userInitiated) {
                        try? await Legendary.command(arguments: [
                            "import",
                            checkIntegrity ? nil : "--disable-check",
                            withDLCs ? "--with-dlcs" : "--skip-dlcs",
                            "--platform", platform == .macOS ? "Mac" : platform == .windows ? "Windows" : "Mac",
                            game.id,
                            path
                        ] .compactMap { $0 }, identifier: "epicImport") { output in
                            if output.stderr.contains("INFO: Game \"\(game.title)\" has been imported.") {
                                isPresented = false
                            }
                            
                            if let match = try? Regex(#"(ERROR|CRITICAL): (.*)"#).firstMatch(in: output.stderr) {
                                isOperating = false
                                errorDescription = .init(match[1].substring ?? "Unknown Error")
                                isErrorAlertPresented = true
                            }
                            
                            // legendary/cli.py line 1372 as of hash 4507842
                            if output.stderr.contains(
                                "Some files are missing from the game installation, install may not"
                                + " match latest Epic Games Store version or might be corrupted."
                            ) {
                                // TODO: implement
                            }
                        }
                    }
                }
                .disabled(path.isEmpty)
                .disabled(game.title.isEmpty)
                .disabled(supportedPlatforms == nil)
                .disabled(isOperating)
                .buttonStyle(.borderedProminent)
            }
            
            .task(priority: .userInitiated) {
                let games = try? Legendary.getInstallable()
                guard let games = games, !games.isEmpty else { return }
                installableGames = games.filter { (try? !Legendary.getInstalledGames().contains($0)) ?? true }
                if let game = installableGames.first { self.game = game }
                isOperating = false
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
            
            .alert(isPresented: $isErrorAlertPresented) {
                Alert(
                    title: .init("Error importing game \"\(game.title)\"."),
                    message: .init(errorDescription),
                    dismissButton: .default(.init(""))
                )
            }
            
            .onChange(of: isErrorAlertPresented) {
                if !$1 { errorDescription = .init() }
            }
        }
    }
}

#Preview {
    GameImportView.Epic(isPresented: .constant(true))
}
