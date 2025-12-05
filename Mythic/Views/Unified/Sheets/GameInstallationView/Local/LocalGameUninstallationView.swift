//
//  LocalGameUninstallationView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 5/12/2025.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import OSLog

struct LocalGameUninstallationView: View {
    @Binding var game: LocalGame
    @Binding var isPresented: Bool
    @Bindable var gameListViewModel: GameListViewModel = .shared
    
    @State private var isImageEmpty: Bool = true
    @State var isOperating: Bool = false

    @State private var removeFromDisk: Bool = true
    
    var body: some View {
        BaseGameInstallationView(
            game: .init(get: { return game as Game },
                        set: {
                            if let castGame = $0 as? LocalGame {
                                game = castGame
                            }
                        }), isPresented: $isPresented,
            isImageEmpty: $isImageEmpty,
            type: "Uninstall",
            operating: $isOperating,
            action: {
                _ = try await LocalGameManager.uninstall(game: game,
                                                          persistFiles: !removeFromDisk)
            },
            content: {
                Form {
                    Toggle("Remove files from disk",
                           systemImage: "trash",
                           isOn: $removeFromDisk)
                }
                .formStyle(.grouped)
            }
        )
        .navigationTitle("Uninstall \(game.description)")
    }
}

#Preview {
    LocalGameUninstallationView(game: .constant(placeholderGame(type: LocalGame.self)),
                                    isPresented: .constant(true))
        .padding()
}
