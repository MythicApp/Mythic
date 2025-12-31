//
//  EpicGamesGameImportView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/1/2024.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import SwordRPC
import OSLog
import UniformTypeIdentifiers

struct EpicGamesGameImportView: View {
    @Bindable var gameDataStore: GameDataStore = .shared
    
    @Binding var isPresented: Bool
    @State private var errorDescription: String = .init()
    @State private var isErrorAlertPresented = false
    
    @State private var game: EpicGamesGame = .init(id: .init(),
                                                   title: .init(),
                                                   installationState: .uninstalled)
    
    @State private var isRetrievingSupportedPlatforms: Bool = false
    @State private var supportedPlatforms: [Game.Platform]?
    @State private var platform: Game.Platform = .macOS
    @State private var enclosingDirectory: URL?
    
    private var installableGames: [EpicGamesGame] {
        gameDataStore.library
            .compactMap { $0 as? EpicGamesGame }
            .sorted(by: { $0.title < $1.title })
            .filter({ $0.installationState == .uninstalled })
    }
    
    @State private var withDLCs: Bool = true
    @State private var checkIntegrity: Bool = true
    
    @State private var isImageEmpty: Bool = true
    
    @State private var isOperating: Bool = false
    
    @State private var isGameLocationFileImporterPresented: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                GameImageCard(game: game, url: game.verticalImageURL, isImageEmpty: $isImageEmpty)
                    .aspectRatio(3/4, contentMode: .fit)
                    .padding([.top, .leading])
                
                Form {
                    Picker(
                        "Game",
                        systemImage: "gamecontroller",
                        selection: $game
                    ) {
                        ForEach(installableGames) { game in
                            Text(game.title)
                                .tag(game)
                        }
                    }
                    .onAppear(perform: { game = installableGames.first ?? game })
                    
                    // FIXME: shared with EpicImport
                    Picker(
                        "Platform",
                        systemImage: "desktopcomputer.and.arrow.down",
                        selection: $platform
                    ) {
                        ForEach(supportedPlatforms ?? .init(), id: \.self) { platform in
                            Text(platform.description)
                        }
                    }
                    .onChange(of: game) {
                        isRetrievingSupportedPlatforms = true
                        if let retrievedSupportedPlatforms = game.getSupportedPlatforms() {
                            supportedPlatforms = Array(retrievedSupportedPlatforms)
                        }
                        isRetrievingSupportedPlatforms = false
                    }
                    .withOperationStatus(
                        operating: $isRetrievingSupportedPlatforms,
                        successful: .constant(nil),
                        observing: $supportedPlatforms,
                        action: { // update platform value so picker is never undefined
                            // sort to prioritise macOS first
                            let platforms = supportedPlatforms?.sorted(by: { $0 == .macOS && $1 != .macOS })
                            platform = platforms?.first ?? platform
                        }
                    )
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Location", systemImage: "folder")
                            Text(enclosingDirectory?.prettyPath ?? "Unknown")
                                .foregroundStyle(.secondary)
                        }
                        
                        if let enclosingDirectory {
                            if !FileManager.default.isReadableFile(atPath: enclosingDirectory.path) {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolVariant(.fill)
                                    .help("File/Folder is not readable by Mythic.")
                            }
                        }
                        
                        Spacer()
                        
                        Button("Browse...") {
                            isGameLocationFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isGameLocationFileImporterPresented,
                            allowedContentTypes: [.folder]
                        ) { result in
                            if case .success(let success) = result {
                                enclosingDirectory = success
                            }
                        }
                    }
                    .help("Select the folder that encloses your game's files.")
                    
                    Toggle("Import with DLCs", systemImage: "puzzlepiece.extension", isOn: $withDLCs)
                    
                    Toggle("Verify game files' integrity", systemImage: "checkmark.app", isOn: $checkIntegrity)
                }
                .formStyle(.grouped)
            }
            
            HStack {
                Button("Cancel", role: .cancel) { isPresented = false }
                
                Spacer()
                
                OperationButton(
                    "Done",
                    operating: $isOperating,
                    successful: .constant(nil),
                    placement: .leading
                ) {
                    guard let enclosingDirectory else { return }
                    
                    try? await EpicGamesGameManager.importGame(game,
                                                               in: enclosingDirectory,
                                                               repairIfNecessary: checkIntegrity,
                                                               withDLCs: withDLCs,
                                                               platform: platform)
                    
                    isPresented = false
                }
                .disabled(enclosingDirectory == nil)
                .disabled(supportedPlatforms?.isEmpty == true)
                .disabled(isOperating)
                .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .bottom])
        }
        .alert("Error importing game \"\(game.title)\".",
               isPresented: $isErrorAlertPresented,
               presenting: errorDescription) { _ in
            if #available(macOS 26.0, *) {
                Button("OK", role: .close, action: {})
            } else {
                Button("OK", role: .cancel, action: {})
            }
        } message: { description in
            Text(description)
        }
        .onChange(of: isErrorAlertPresented) {
            if !$1 { errorDescription = .init() }
        }
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence = RichPresence()
                presence.details = "Importing & Configuring \"\(game.title)\"."
                presence.state = "Importing \(game.title)"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                return presence
            }())
        }
    }
}

#Preview {
    EpicGamesGameImportView(isPresented: .constant(true))
}
