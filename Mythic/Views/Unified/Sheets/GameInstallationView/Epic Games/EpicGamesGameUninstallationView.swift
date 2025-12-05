//
//  EpicGamesGameUninstallationView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 6/3/2024.
//

import SwiftUI
import OSLog

struct EpicGamesGameUninstallationView: View {
    @Binding var game: EpicGamesGame
    @Binding var isPresented: Bool
    @Bindable var gameListViewModel: GameListViewModel = .shared
    
    @State private var isImageEmpty: Bool = true
    @State var isOperating: Bool = false

    @State private var removeFromDisk: Bool = true
    @State private var runUninstaller: Bool = true
    
    var body: some View {
        BaseGameInstallationView(
            game: .init(get: { return game as Game },
                        set: {
                            if let castGame = $0 as? EpicGamesGame {
                                game = castGame
                            }
                        }), isPresented: $isPresented,
            isImageEmpty: $isImageEmpty,
            type: "Uninstall",
            operating: $isOperating,
            action: {
                Task(priority: .userInitiated) { @MainActor [game] in
                    _ = try await EpicGamesGameManager.uninstall(game: game,
                                                                  persistFiles: !removeFromDisk,
                                                                  runUninstallerIfPossible: runUninstaller)
                }
            },
            content: {
                Form {
                    Toggle("Remove files from disk",
                           systemImage: "trash",
                           isOn: $removeFromDisk)

                    Toggle("Run specialised game uninstaller",
                           systemImage: "progress.indicator",
                           isOn: $runUninstaller)
                }
                .formStyle(.grouped)
            }
        )
        .navigationTitle("Uninstall \(game.description)")
    }
}

#Preview {
    EpicGamesGameUninstallationView(game: .constant(placeholderGame(type: EpicGamesGame.self)),
                                    isPresented: .constant(true))
        .padding()
}
