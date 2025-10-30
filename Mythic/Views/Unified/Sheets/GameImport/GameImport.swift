//
//  ImportGameView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 29/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import OSLog

struct GameImportView: View {
    @Binding var isPresented: Bool
    @ObservedObject var gameListViewModel: GameListVM = .shared

    @State private var source: Game.Source = .epic
    
    // MARK: - Body
    var body: some View {
        VStack {
            if #available(macOS 15.0, *) {
                TabView {
                    Tab("Epic", systemImage: "gamecontroller") {
                        GameImportView.Epic(isPresented: $isPresented)
                    }

                    Tab("Steam", systemImage: "gamecontroller") {
                        
                    }
                    .hidden()

                    Tab("Local", systemImage: "gamecontroller") {
                        GameImportView.Local(isPresented: $isPresented)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                .tabViewSidebarHeader(content: { Text("Select a source:") })
            } else {
                TabView {
                    GameImportView.Epic(isPresented: $isPresented)
                        .tabItem {
                            Label("Epic", systemImage: "gamecontroller")
                        }

                    GameImportView.Local(isPresented: $isPresented)
                        .tabItem {
                            Label("Local", systemImage: "gamecontroller")
                        }
                }
                .padding()
            }
        }
        .navigationTitle("Import")
        .frame(minWidth: 750, minHeight: 300, idealHeight: 350)
        .onChange(of: isPresented) {
            if !$1 { gameListViewModel.refresh() }
        }
    }
}

#Preview {
    GameImportView(isPresented: .constant(true))
}
