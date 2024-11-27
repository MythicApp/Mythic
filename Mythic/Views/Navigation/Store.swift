//
//  Store.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

import SwiftUI
import SwordRPC

struct StoreView: View {
    @State private var loadingError: Error?
    @State private var isLoading: Bool = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var url: URL = .init(string: "https://store.epicgames.com/")!
    @State private var refreshAnimation: Double = 0
    
    var body: some View {
        WebView(url: url, error: $loadingError, isLoading: $isLoading, canGoBack: $canGoBack, canGoForward: $canGoForward)
            .navigationTitle("Store")
            .task(priority: .background) {
                updateDiscordPresence()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: goBack) {
                        Image(systemName: "arrow.left.circle")
                    }
                    .disabled(!canGoBack)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: goForward) {
                        Image(systemName: "arrow.right.circle")
                    }
                    .disabled(!canGoForward)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: refreshPage) {
                        Image(systemName: "arrow.clockwise.circle")
                            .rotationEffect(.degrees(refreshAnimation))
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: openInBrowser) {
                        Image(systemName: "arrow.up.forward")
                    }
                }
            }
    }
    
    private func updateDiscordPresence() {
        discordRPC.setPresence {
            var presence = RichPresence()
            presence.details = "Currently browsing \(url)"
            presence.state = "Looking for games to purchase"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }()
    }
    
    private func goBack() {
        if canGoBack {
            url = URL(string: "javascript:history.back();")!
        }
    }
    
    private func goForward() {
        if canGoForward {
            url = URL(string: "javascript:history.forward();")!
        }
    }
    
    private func refreshPage() {
        url = URL(string: "javascript:location.reload();")!
        withAnimation {
            refreshAnimation = 360
        }
        refreshAnimation = 0
    }
    
    private func openInBrowser() {
        workspace.open(url)
    }
}

#Preview {
    StoreView()
}
