//
//  SteamGameUninstallationView.swift
//  Mythic
//

import SwiftUI

struct SteamGameUninstallationView: View {
    @Binding var game: SteamGame
    @Binding var isPresented: Bool
    @Bindable var gameListViewModel: GameListViewModel = .shared

    @State private var isImageEmpty = true
    @State var isOperating = false

    var body: some View {
        BaseGameInstallationView(
            game: .init(get: { game as Game },
                        set: {
                            if let castGame = $0 as? SteamGame {
                                game = castGame
                            }
                        }),
            isPresented: $isPresented,
            isImageEmpty: $isImageEmpty,
            type: "Uninstall",
            operating: $isOperating,
            action: {
                _ = try await SteamGameManager.uninstall(game: game, persistFiles: false)
            },
            content: {
                Text("Steam's own uninstaller will open to complete the removal.")
                    .foregroundStyle(.secondary)
            }
        )
        .navigationTitle("Uninstall \(game.description)")
    }
}

#Preview {
    SteamGameUninstallationView(game: .constant(placeholderGame(type: SteamGame.self)),
                                isPresented: .constant(true))
        .padding()
}
