//
//  UninstallGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 6/3/2024.
//

import SwiftUI
import OSLog

struct UninstallViewEvo: View {
    @Binding var game: Game
    @Binding var isPresented: Bool
    @ObservedObject var gameListViewModel: GameListVM = .shared

    @State private var deleteFiles: Bool = true
    @State private var runUninstaller: Bool
    @State private var isConfirmationPresented: Bool = false
    
    @State var uninstalling: Bool = false
    
    @State private var isUninstallationErrorPresented: Bool = false
    @State private var uninstallationErrorReason: String?
    
    init(game: Binding<Game>, isPresented: Binding<Bool>) {
        self._game = game
        self._isPresented = isPresented
        self.runUninstaller = (game.wrappedValue.source != .local)
    }
    
    var body: some View {
        VStack {
            Text("Uninstall \"\(game.title)\"")
                .font(.title)
                .padding([.horizontal, .top])

            Form {
                Toggle(isOn: $deleteFiles) {
                    Text("Remove game files")
                }

                Toggle(isOn: $runUninstaller) {
                    Text("Run specialised uninstaller (If applicable)")
                }
                .disabled(game.source == .local)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .disabled(uninstalling)
                
                Spacer()
                    .alert(isPresented: $isUninstallationErrorPresented) {
                        Alert(
                            title: .init("Unable to uninstall \"\(game.title)\"."),
                            message: .init(uninstallationErrorReason ?? "Unknown Error.")
                        )
                    }
                HStack {
                    if uninstalling {
                        ProgressView()
                            .controlSize(.small)
                            .padding(0.5)
                    }
                    Button("Uninstall") {
                        isConfirmationPresented = true
                    }
                    .disabled(uninstalling)
                }
                .buttonStyle(.borderedProminent)
                .alert(isPresented: $isConfirmationPresented) {
                    Alert(
                        title: Text("Are you sure you want to uninstall \"\(game.title)\"?"),
                        primaryButton: .destructive(Text("Uninstall")) {
                            switch game.source {
                            case .epic:
                                Task(priority: .userInitiated) {
                                    withAnimation { uninstalling = true }
                                    do {
                                        try await Legendary.command(arguments: [
                                            "-y", "uninstall",
                                            deleteFiles ? nil : "--keep-files",
                                            runUninstaller ? nil : "--skip-uninstaller",
                                            game.id
                                        ] .compactMap { $0 }, identifier: "uninstall") { output in
                                            guard output.stderr.contains("ERROR:") else { return }
                                            let errorLine = output.stderr.trimmingPrefix(try! Regex(#"\[(.*?)\]"#)).trimmingPrefix("ERROR: ")
                                            // swiftlint:disable:previous force_try
                                            guard !errorLine.contains("OSError(66, 'Directory not empty')") || !errorLine.contains("please remove manually") else {
                                                if let gamePath = game.path { try? files.removeItem(atPath: gamePath) }
                                                return
                                            }
                                            
                                            uninstallationErrorReason = String(errorLine)
                                            isUninstallationErrorPresented = true
                                        }
                                    } catch {
                                        uninstallationErrorReason = error.localizedDescription
                                        isUninstallationErrorPresented = true
                                    }
                                    
                                    withAnimation { uninstalling = false }
                                }
                            case .local:
                                do {
                                    guard let gamePath = game.path else { throw FileLocations.FileDoesNotExistError(.init(filePath: game.path ?? .init())) }
                                    withAnimation { uninstalling = true }

                                    if files.fileExists(atPath: gamePath),
                                       deleteFiles {
                                        try files.removeItem(atPath: gamePath)
                                    }

                                    LocalGames.library?.remove(game)
                                    withAnimation { uninstalling = false }
                                    isPresented = false
                                } catch {
                                    uninstallationErrorReason = error.localizedDescription
                                    isUninstallationErrorPresented = true
                                }
                            }
                            
                            favouriteGames.remove(game.id)
                            if let recentlyPlayedObject = defaults.object(forKey: "recentlyPlayed") as? Data,
                               let recentlyPlayedGame: Game = try? PropertyListDecoder().decode(Game.self, from: recentlyPlayedObject),
                               recentlyPlayedGame == game {
                                defaults.removeObject(forKey: "recentlyPlayed")
                            }

                            gameListViewModel.refresh()
                            isPresented = false
                        },
                        secondaryButton: .cancel(Text("Cancel")) {
                            isConfirmationPresented = false
                        }
                    )
                }
            }
            .padding([.horizontal, .bottom])
        }
    }
}

#Preview {
    UninstallViewEvo(game: .constant(.init(source: .local, title: .init())), isPresented: .constant(true))
}
