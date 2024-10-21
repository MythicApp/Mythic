//
//  Store.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct StoreView: View {
    @State private var loadingError: Error?
    @State private var isLoading: Bool? = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var url: URL = .init(string: "https://store.epicgames.com/")!
    @State private var refreshAnimation: Angle = .degrees(0)
    
    var body: some View {
        WebView(url: url, error: .constant(nil), isLoading: .constant(nil), canGoBack: canGoBack, canGoForward: canGoForward)
        
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
            // FIXME: Loading view update creates view update race condition with webview
            /*
             if isLoading {
                ToolbarItem(placement: .confirmationAction) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
             } else if loadingError {
                ToolbarItem(placement: .confirmationAction) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolEffect(.pulse)
                }
             }
             */
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if canGoBack {
                        url = .init(string: "javascript:history.back();")!
                    }
                } label: {
                    Image(systemName: "arrow.left.circle")
                }
                .disabled(!canGoBack)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if canGoForward {
                        url = .init(string: "javascript:history.forward();")!
                    }
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .disabled(!canGoForward)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    url = .init(string: "javascript:location.reload();")!
                    withAnimation(.default) {
                        refreshAnimation = .degrees(360)
                    } completion: {
                        refreshAnimation = .degrees(0)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .rotationEffect(refreshAnimation) // thx whisky
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
