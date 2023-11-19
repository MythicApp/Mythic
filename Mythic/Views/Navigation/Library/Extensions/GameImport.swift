//
//  AddGameView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

extension LibraryView {
    struct GameImportView: View {
        @Binding var isPresented: Bool
        @Binding var isGameListRefreshCalled: Bool

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
                    .onHover {_ in
                        print("\(selectedGame)")
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
                            print("seel \(selectedGame)")
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
                                        useCache: false
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

                                            if line.contains("Some files are missing from the game installation, install may not match latest Epic Games Store version or might be corrupted.") { // legendary/cli.py line 1372 as of hash 4507842

                                            }
                                        }
                                    }
                                }

                                /*
                                 Output when importing Genshin Impact
                                 [Core] INFO: Trying to re-use existing login session...
                                 [Core] INFO: Downloading latest manifest for "41869934302e4b8cafac2d3c0e7c293d"
                                 [cli] INFO: Game install appears to be complete.
                                 [cli] INFO: NOTE: The Game installation will have to be verified before it can be updated with legendary.
                                 [cli] INFO: Run "legendary repair 41869934302e4b8cafac2d3c0e7c293d" to do so.
                                 [cli] INFO: Game "Genshin Impact" has been imported.
                                 
                                 conclusion: repair still has to be ran for full checksum matching
                                 */
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
