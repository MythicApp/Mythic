//
//  GameUninstall.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI
import OSLog

extension GameListView {
    struct UninstallView: View {
        @Binding var isPresented: Bool
        public var game: Legendary.Game
        @Binding var isGameListRefreshCalled: Bool

        @Binding var activeAlert: GameListView.ActiveAlert
        @Binding var isAlertPresented: Bool
        @Binding var failedGame: Legendary.Game?

        @Binding var uninstallationErrorMessage: Substring

        @State private var keepFiles: Bool = false
        @State private var skipUninstaller: Bool = false

        @State private var isProgressViewSheetPresented = false
        @State private var isConfirmationPresented = false

        var body: some View {
            VStack {
                Text("Uninstall \(game.title)")
                    .font(.title)

                Spacer()

                HStack {
                    Toggle(isOn: $keepFiles) {
                        Text("Keep files")
                    }
                    Spacer()
                }

                HStack {
                    Toggle(isOn: $skipUninstaller) {
                        Text("Don't run uninstaller")
                    }
                    Spacer()
                }

                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }

                    Spacer()

                    Button("Uninstall") {
                        isConfirmationPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            .sheet(isPresented: $isProgressViewSheetPresented) {
                ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
            }

            .alert(isPresented: $isConfirmationPresented) {
                Alert(
                    title: Text("Are you sure you want to uninstall \(game.title)?"),
                    primaryButton: .destructive(Text("Uninstall")) {
                        isPresented = false
                        isProgressViewSheetPresented = true

                        Task {
                            let commandOutput = await Legendary.command(
                                args: [
                                    "-y", "uninstall",
                                    keepFiles ? "--keep-files" : nil,
                                    skipUninstaller ? "--skip-uninstaller" : nil,
                                    game.appName
                                ]
                                    .compactMap { $0 },
                                useCache: false,
                                identifier: "uninstall"
                            )

                            if let commandStderrString = String(data: commandOutput.stderr, encoding: .utf8) {
                                for line in commandStderrString.components(separatedBy: "\n")
                                where line.contains("ERROR:") {
                                    if let range = line.range(of: "ERROR: ") {
                                        let substring = line[range.upperBound...]
                                        isProgressViewSheetPresented = false
                                        uninstallationErrorMessage = substring
                                        failedGame = game
                                        activeAlert = .uninstallError
                                        isAlertPresented = true
                                        Logger.app.error("Uninstall error: \(substring)")
                                        isGameListRefreshCalled = true
                                        return // first error only
                                    }
                                }

                                if !commandStderrString.isEmpty {
                                    if commandStderrString.contains("INFO: Game has been uninstalled.") {
                                        isProgressViewSheetPresented = false
                                        isPresented = false
                                    }
                                }
                            }

                            isGameListRefreshCalled = true
                        }
                    },
                    secondaryButton: .cancel(Text("Cancel")) {
                        isAlertPresented = false
                    }
                )
            }
        }
    }
}

#Preview {
    GameListView.UninstallView(
        isPresented: .constant(true),
        game: .init(
            appName: "[appName]",
            title: "[title]"
        ),
        isGameListRefreshCalled: .constant(false),
        activeAlert: .constant(.installError),
        isAlertPresented: .constant(false),
        failedGame: .constant(
            .init(
                appName: "[appName]",
                title: "[title]"
            )
        ),
        uninstallationErrorMessage: .constant(Substring())
    )
}
