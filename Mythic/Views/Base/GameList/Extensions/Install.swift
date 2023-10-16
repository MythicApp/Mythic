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
        @Binding var game: Legendary.Game
        @Binding var optionalPacks: [String: String]
        @Binding var isGameListRefreshCalled: Bool
        
        @State private var isToggledDictionary: [String: Bool] = [:]
        
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
                    
                    Button(action: {
                        Task(priority: .userInitiated) {
                            await Legendary.installGame(game: game, optionalPacks: Array(isToggledDictionary.filter { $0.value == true }.keys))
                            isToggledDictionary.removeAll()
                            optionalPacks.removeAll()
                        }
                        isGameListRefreshCalled = true
                        isPresented = false
                    }) {
                        Text("Install")
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
        }
    }
}


#Preview {
    LibraryView()
}
