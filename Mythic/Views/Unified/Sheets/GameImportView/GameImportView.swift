//
//  GameImportView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 29/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import OSLog

struct GameImportView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            if #available(macOS 15.0, *) {
                TabView {
                    Tab("Epic", image: "EGFaceless") {
                        EpicGamesGameImportView(isPresented: $isPresented)
                    }
                    
                    Tab("Steam", image: "Steam") {
                        SteamGameImportView(isPresented: $isPresented)
                    }
                    
                    Tab("Local", systemImage: "storefront") {
                        LocalGameImportView(isPresented: $isPresented)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                .tabViewSidebarHeader(content: { Text("Select storefront:") })
            } else {
                TabView {
                    EpicGamesGameImportView(isPresented: $isPresented)
                        .tabItem {
                            Label { Text("Epic") } icon: { Image("EGFaceless") }
                        }
                    
                    SteamGameImportView(isPresented: $isPresented)
                        .tabItem {
                            Label { Text("Steam") } icon: { Image("Steam") }
                        }

                    LocalGameImportView(isPresented: $isPresented)
                        .tabItem {
                            Label("Local", systemImage: "storefront")
                        }
                }
                .padding()
            }
        }
        .navigationTitle("Import Game")
        .frame(minWidth: 750, minHeight: 300, idealHeight: 350)
    }
}

#Preview {
    GameImportView(isPresented: .constant(true))
}
