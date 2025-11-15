//
//  UninstallGame.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 6/3/2024.
//

import SwiftUI
import OSLog

struct UninstallGameView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool
    @ObservedObject var gameListViewModel: GameListViewModel = .shared

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
                            Task(priority: .userInitiated) {
                                do {
                                    withAnimation { uninstalling = true }
                                    switch game.source {
                                    case .epic:
                                        try await Legendary.uninstall(game: game,
                                                                      deleteFiles: deleteFiles,
                                                                      runUninstaller: runUninstaller)
                                    case .local:
                                        try await LocalGames.uninstall(game: game, deleteFiles: deleteFiles)
                                    }
                                } catch {
                                    uninstallationErrorReason = error.localizedDescription
                                    isUninstallationErrorPresented = true
                                }
                                withAnimation { uninstalling = false }
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
    UninstallGameView(game: .constant(placeholderGame(forSource: .local)), isPresented: .constant(true))
}
