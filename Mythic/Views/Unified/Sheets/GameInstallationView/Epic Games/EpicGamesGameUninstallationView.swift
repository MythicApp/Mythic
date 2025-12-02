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

    @State private var removeFromDisk: Bool = true
    @State private var runUninstaller: Bool = true // FIXME: only applies for legendary games
    @State private var isConfirmationPresented: Bool = false
    
    @State var isUninstallationButtonOperating: Bool = false

    @State private var isUninstallationErrorPresented: Bool = false
    @State private var uninstallationErrorReason: String?
    
    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            HStack {
                GameImageCard(url: game.verticalImageURL, isImageEmpty: .constant(false))
                    .aspectRatio(3/4, contentMode: .fit)

                VStack {
                    Text("Uninstall \(game.description)")
                        .font(.title)
                        .bold()

                    if let storefront = game.storefront {
                        SubscriptedTextView(storefront.description)
                    }

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
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }

                Spacer()

                OperationButton(
                    "Uninstall",
                    operating: $isUninstallationButtonOperating,
                    successful: .constant(nil),
                    placement: .leading
                ) {
                    Task { @MainActor [game] in
                        let operation = try await EpicGamesGameManager.uninstall(game: game,
                                                                                 persistFiles: !removeFromDisk,
                                                                                 runUninstallerIfPossible: runUninstaller)

                        self.isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .navigationTitle("Uninstall \(game.description)")
    }
}

#Preview {
    EpicGamesGameUninstallationView(game: .constant(placeholderGame(type: EpicGamesGame.self)),
                                    isPresented: .constant(true))
        .padding()
}
