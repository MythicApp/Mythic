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

    var body: some View {
        VStack {
            if #available(macOS 15.0, *) {
                TabView {
                    Tab("Epic", systemImage: "storefront") {
                        GameImportView.Epic(isPresented: $isPresented)
                    }
                    
                    Tab("Steam", systemImage: "storefront") {

                    }
                    .hidden()
                    
                    Tab("Local", systemImage: "storefront") {
                        GameImportView.Local(isPresented: $isPresented)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                .tabViewSidebarHeader(content: { Text("Select storefront:") })
            } else {
                TabView {
                    GameImportView.Epic(isPresented: $isPresented)
                        .tabItem {
                            Label("Epic", systemImage: "storefront")
                        }
                    
                    GameImportView.Local(isPresented: $isPresented)
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
