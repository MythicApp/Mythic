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

import SwiftUI

struct StoreView: View {
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var urlString = "https://store.epicgames.com/"
    
    var body: some View {
        WebView(
            loadingError: $loadingError,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            isLoading: $isLoading,
            urlString: urlString
        )
        
        .toolbar {
            /*
             KNOWN ISSUE:
             updateNSView in WebView() is an async function, 
             and the the view is being updated while the page is still loading
             
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
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "globe.europe.africa.fill")
                }
            }
        }
        
        .alert(isPresented: $loadingError) {
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
