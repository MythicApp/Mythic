//
//  Store.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

import SwiftUI

struct StoreView: View {
    
    @State private var loadingError = false
    @State private var isLoading = false
    @State private var notImplementedAlert = false
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
            
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    if canGoBack {
                        urlString = "javascript:history.back();"
                    }
                }) {
                    Image(systemName: "arrow.left.circle")
                }
                .disabled(!canGoBack)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    if canGoForward {
                        urlString = "javascript:history.forward();"
                    }
                }) {
                    Image(systemName: "arrow.right.circle")
                }
                .disabled(!canGoForward)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    urlString = "javascript:location.reload();"
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                }
            }
        }
        
        .alert(isPresented: $loadingError) {
            Alert(
                title: Text("Error"),
                message: Text("Failed to load the webpage."),
                primaryButton: .default(Text("Retry")) {
                    _ = NotImplemented()
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    loadingError = false
                }
            )
        }
    }
}

extension View {
    func NavigationLinkWrapper<Content: View>(label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        NavigationLink(destination: content()) {
            Label(label, systemImage: "star")
        }
    }
}
