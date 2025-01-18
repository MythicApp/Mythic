//
//  StoreView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/9/2023.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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
                forIdentifier: (
                    .init(uuidString: webDataStoreIdentifierString)
                    ?? WKWebsiteDataStore.default().identifier
                )!
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
