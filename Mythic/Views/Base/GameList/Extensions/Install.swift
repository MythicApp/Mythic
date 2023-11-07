//
//  GameInstall.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

extension GameListView {
    struct InstallView: View {
        @Binding var isPresented: Bool
        public var game: Legendary.Game
        @Binding var optionalPacks: [String: String]
        @Binding var isGameListRefreshCalled: Bool
        
        @Binding var isAlertPresented: Bool
        @Binding var activeAlert: GameListView.ActiveAlert
        @Binding var installationErrorMessage: String
        @Binding var failedGame: Legendary.Game?
        
        @State private var isToggledDictionary: [String: Bool] = Dictionary()
        
        var body: some View {
            VStack {
                Text("Install \(game.title)")
                    .font(.title)
                if !optionalPacks.isEmpty {
                    Text("(supports selective downloads.)")
                        .font(.footnote)
                        .foregroundStyle(.placeholder)
                }
                
                Divider()
                
                if !optionalPacks.isEmpty {
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
                            ) { }
                        }
                    }
                }
                
                HStack {
                    Button("Close") {
                        isPresented = false
                    }
                    
                    Button("Install") {
                        Task(priority: .userInitiated) {
                            isPresented = false
                            do {
                                try await Legendary.install(
                                    game: game,
                                    optionalPacks: Array(isToggledDictionary.filter { $0.value == true }.keys)
                                )
                                
                                isGameListRefreshCalled = true
                            }
                            catch {
                                switch error {
                                case let error as Legendary.InstallationError:
                                    failedGame = game
                                    installationErrorMessage = error.message
                                    activeAlert = .installError
                                    isAlertPresented = true
                                default:
                                    print()
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .fixedSize()
            .onAppear {
                if !optionalPacks.isEmpty {
                    for (_, tag) in optionalPacks {
                        isToggledDictionary[tag] = false
                    }
                }
            }
            .onDisappear {
                isToggledDictionary.removeAll()
                optionalPacks.removeAll()
            }
        }
    }
}


#Preview {
    GameListView.InstallView(
        isPresented: .constant(true),
        game: .init(
            appName: "[appName]",
            title: "[title]"
        ),
        optionalPacks: .constant(Dictionary()),
        isGameListRefreshCalled: .constant(false),
        isAlertPresented: .constant(false),
        activeAlert: .constant(.installError),
        installationErrorMessage: .constant(String()),
        failedGame: .constant(
            .init(
                appName: "[appName]",
                title: "[title]"
            )
        )
    )
}
