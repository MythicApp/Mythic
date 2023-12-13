//
//  WebView.swift
//  Mythic
//
// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎]

import SwiftUI
import WebKit
import OSLog

// MARK: - WebView Struct
/// SwiftUI view representing a WebView.
struct WebView: NSViewRepresentable {
    
    // MARK: - Bindings
    @Binding var loadingError: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    
    // MARK: - Variables
    var urlString: String
    
    // MARK: - Logger
    /// Logger for the WebView.
    let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "WebView"
    )
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
    
    // MARK: - Make Coordinator
    /// Creates and returns the Coordinator instance for the WebView.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator Class
    /// Coordinator class for handling WebView navigation events.
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // MARK: - Did Fail Provisional Navigation
        /// Called when a navigation fails.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
            DispatchQueue.main.async { [self] in
                parent.log.error("\(error)")
                parent.loadingError = true
            }
        }
        
        // MARK: - Did Finish Navigation
        /// Called when navigation finishes successfully.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            DispatchQueue.main.async { [self] in
                parent.canGoBack = webView.canGoBack
                parent.canGoForward = webView.canGoForward
                parent.isLoading = false
                parent.loadingError = false
            }
        }
        
        // MARK: - Did Start Provisional Navigation
        /// Called when the WebView starts provisional navigation.
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
            DispatchQueue.main.async { [self] in
                parent.isLoading = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WebView(
        loadingError: .constant(false),
        canGoBack: .constant(false),
        canGoForward: .constant(false),
        isLoading: .constant(false),
        urlString: "https://example.com"
    )
}
