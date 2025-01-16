//
//  ImportGameView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 29/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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
                        NotImplementedView()
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
