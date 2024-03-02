//
//  Store.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct StoreView: View {
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    @State private var refreshAnimation: Angle = .degrees(0)
    
    var body: some View {
        WebView(
            loadingError: $loadingError,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            isLoading: $isLoading,
            urlString: urlString
        )
        
        .navigationTitle("Store")
        
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Currently browsing \(urlString)"
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
                        urlString = "javascript:history.back();"
                    }
                } label: {
                    Image(systemName: "arrow.left.circle")
                }
                .disabled(!canGoBack)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if canGoForward {
                        urlString = "javascript:history.forward();"
                    }
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .disabled(!canGoForward)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    urlString = "javascript:location.reload();"
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
                    if let url = URL(string: urlString) {
                        workspace.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.forward")
                }
            }
        }
        
        .alert(isPresented: $loadingError) { // FIXME: Error pops up continuously, making Mythic unusable.
            Alert(
                title: Text("Error"),
                message: Text("Failed to load the webpage."),
                primaryButton: .default(Text("Retry")) {
                    _ = NotImplementedView()
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    loadingError = false
                }
            )
        }
    }
}

#Preview {
    StoreView()
}
