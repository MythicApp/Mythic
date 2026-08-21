//
//  SteamGameUninstallationView.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import OSLog

struct SteamGameUninstallationView: View {
    @Binding var game: SteamGame
    @Binding var isPresented: Bool

    @State private var isImageEmpty: Bool = true
    @State var isOperating: Bool = false

    @State private var removeFromDisk: Bool = true

    var body: some View {
        BaseGameInstallationView(
            game: .init(get: { game as Game },
                        set: { if let castGame = $0 as? SteamGame { game = castGame } }),
            isPresented: $isPresented,
            isImageEmpty: $isImageEmpty,
            type: "Uninstall",
            operating: $isOperating,
            action: {
                _ = try await SteamGameManager.uninstall(steamGame: game, persistingFiles: !removeFromDisk)
            },
            content: {
                Form {
                    Toggle("Remove files from disk", systemImage: "trash", isOn: $removeFromDisk)

                    if let sizeOnDisk = game.appManifest?.sizeOnDisk {
                        LabeledContent("Reclaims",
                                       value: sizeOnDisk.formatted(.byteCount(style: .file)))
                    }
                }
                .formStyle(.grouped)
            }
        )
        .navigationTitle("Uninstall \(game.description)")
    }
}

#Preview {
    SteamGameUninstallationView(
        game: .constant(.init(appID: "1623730", title: "Palworld", installationState: .uninstalled)),
        isPresented: .constant(true)
    )
    .padding()
}
