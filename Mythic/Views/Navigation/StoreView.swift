//
//  StoreView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import SwordRPC
import WebKit

struct StoreView: View {
    private var canGoBack = false
    private var canGoForward = false
    @State private var url: URL = .init(string: "https://store.epicgames.com/")!

    @State private var refreshIconRotation: Angle = .degrees(0)

    @AppStorage("epicGamesWebDataStoreIdentifierString") var webDataStoreIdentifierString: String = UUID().uuidString

    var body: some View {
        WebView(
            url: url,
            datastore: .init(
                forIdentifier: (.init(uuidString: webDataStoreIdentifierString) ?? WKWebsiteDataStore.default().identifier)!
            ),
            error: .constant(nil),
            canGoBack: canGoBack,
            canGoForward: canGoForward
        )

        .navigationTitle("Store")

        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Currently browsing \(url)"
                presence.state = "Looking for games to purchase"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
        
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if canGoBack {
                        url = .init(string: "javascript:history.back();")!
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .symbolVariant(.circle)
                }
                .disabled(!canGoBack)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if canGoForward {
                        url = .init(string: "javascript:history.forward();")!
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .symbolVariant(.circle)
                }
                .disabled(!canGoForward)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    url = .init(string: "javascript:location.reload();")!
                    withAnimation(.default) {
                        refreshIconRotation = .degrees(360)
                    } completion: {
                        refreshIconRotation = .degrees(0)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolVariant(.circle)
                        .rotationEffect(refreshIconRotation)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    workspace.open(url)
                } label: {
                    Image(systemName: "arrow.up.forward")
                }
            }
        }
    }
}

#Preview {
    StoreView()
}
