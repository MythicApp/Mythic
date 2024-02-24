//
//  GameInstall.swift
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

extension GameListView {
    // MARK: - InstallView
    /// An extension of the `GameListView` that defines the `InstallView` SwiftUI view for installing games.
    struct InstallView: View {
        // MARK: - Bindings
        @Binding var isPresented: Bool
        @Binding var game: Game
        @Binding var optionalPacks: [String: String]
        @Binding var isGameListRefreshCalled: Bool
        @Binding var isAlertPresented: Bool
        @Binding var activeAlert: GameListView.ActiveAlert
        @Binding var installationErrorMessage: String
        @Binding var failedGame: Game?
        
        @State private var platform: GamePlatform = .macOS
        
        // FIXME: make as binding using init() {}
        @State private var supportedPlatforms: [GamePlatform]?
        
        @State var baseURL: URL = Bundle.appGames! // TODO: default base path
        
        // MARK: - State Properties
        /// Dictionary to track the toggled state of optional packs.
        @State private var isToggledDictionary: [String: Bool] = .init()
        
        // MARK: - Body View
        var body: some View {
            VStack {
                Text("Install \"\(game.title)\"")
                    .font(.title)
                if !optionalPacks.isEmpty {
                    Text("(supports selective downloads.)")
                        .font(.footnote)
                        .foregroundStyle(.placeholder)

                    Divider()
                    
                    Form {
                        ForEach(optionalPacks.sorted(by: { $0.key < $1.key }), id: \.key) { name, tag in
                            HStack {
                                VStack {
                                    Text(name)
                                    Text(tag)
                                        .font(.footnote)
                                        .foregroundStyle(.placeholder)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Toggle(
                                    isOn: Binding(
                                        get: { isToggledDictionary[tag] ?? false },
                                        set: { newValue in isToggledDictionary[tag] = newValue }
                                    )
                                ) {  }
                            }
                        }
                    }
                    .formStyle(.grouped)
                }
                
                Form {
                    HStack {
                        VStack {
                            HStack { // FIXME: jank
                                Text("Where do you want the game's base path to be located?")
                                Spacer()
                            }
                            HStack {
                                Text(baseURL.prettyPath())
                                    .foregroundStyle(.placeholder)
                                
                                Spacer()
                            }
                        }
                        
                        Spacer()
                        
                        if !FileLocations.isWritableFolder(url: baseURL) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .help("Folder is not writable.")
                        }
                        
                        Button("Browse...") {
                            let openPanel = NSOpenPanel()
                            openPanel.canChooseDirectories = true
                            openPanel.canChooseFiles = false
                            openPanel.canCreateDirectories = true
                            openPanel.allowsMultipleSelection = false
                            
                            if openPanel.runModal() == .OK {
                                baseURL = openPanel.urls.first!
                            }
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
                        Picker("Choose the game's native platform:", selection: $platform) { // FIXME: some games dont have macos binaries
                            ForEach(supportedPlatforms!, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                
                HStack {
                    Button("Close") {
                        isPresented = false
                    }
                    
                    Spacer()
                    
                    Button("Install") {
                        Task(priority: .userInitiated) {
                            do {
                                try await Legendary.install(
                                    game: game, platform: platform,
                                    optionalPacks: Array(isToggledDictionary.filter { $0.value == true }.keys),
                                    baseURL: baseURL
                                )
                                
                                isGameListRefreshCalled = true
                            } catch {
                                switch error {
                                case let error as Legendary.InstallationError: // TODO: FIXME: isPresented becomes false before error is displayed
                                    failedGame = game
                                    installationErrorMessage = error.message
                                    activeAlert = .installError
                                    isAlertPresented = true
                                default: do {  } // pass
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .fixedSize()
            .task(priority: .high) {
                if !optionalPacks.isEmpty {
                    for (_, tag) in optionalPacks {
                        isToggledDictionary[tag] = false
                    }
                }
            }
            .task(priority: .medium) {
                var platforms: [GamePlatform] = .init()
                if let fetchedPlatforms = try? Legendary.getGameMetadata(game: game)?["asset_infos"].dictionary {
                    if fetchedPlatforms.keys.contains("Windows") { platforms.append(.windows) }
                    if fetchedPlatforms.keys.contains("Mac") { platforms.append(.macOS) }
                    
                    DispatchQueue.main.async {
                        platform = platforms.first!
                    }
                } else {
                    Logger.app.info("Unable to fetch supported platforms for \(game.title)")
                }
            }
            .onDisappear {
                isToggledDictionary.removeAll()
                optionalPacks.removeAll()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GameListView.InstallView(
        isPresented: .constant(true),
        game: .constant(placeholderGame(.local)),
        optionalPacks: .constant(["dud": "dudname", "dud2": "dud2name"]),
        isGameListRefreshCalled: .constant(false),
        isAlertPresented: .constant(false),
        activeAlert: .constant(.installError),
        installationErrorMessage: .constant(.init()),
        failedGame: .constant(placeholderGame(.local))
    )
}
