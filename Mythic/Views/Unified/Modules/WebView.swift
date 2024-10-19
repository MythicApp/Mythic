//
//  WebView.swift
//  Mythic
//
// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import WebKit
import OSLog

// MARK: - WebView Struct
/// SwiftUI view representing a WebView.
struct WebView: NSViewRepresentable {
    
    var url: URL
    
    @Binding var error: Error?
    @Binding var isLoading: Bool?
    var canGoBack: Bool?
    var canGoForward: Bool?
    
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
        let request = URLRequest(url: self.url)
        nsView.load(request)
    }
    
    // MARK: Coordinator Creation
    /// Creates and returns the Coordinator instance for the WebView.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: Coordinator Class
    /// Coordinator class for handling WebView navigation events.
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // MARK: Provisional Navigation Failure
        /// Called when a navigation fails.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
            Task { @MainActor [self] in
                parent.log.error("\(error.localizedDescription)")
                parent.error = error
            }
        }
        
        // MARK: - Provisional Navigation Completion
        /// Called when navigation finishes successfully.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            Task { @MainActor [self] in
                parent.isLoading = false
                parent.canGoBack = webView.canGoBack
                parent.canGoForward = webView.canGoForward
            }
        }
        
        // MARK: - Provisional Navigation Commencing
        /// Called when the WebView starts provisional navigation.
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
            Task { @MainActor [self] in
                parent.isLoading = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WebView(url: .init(string: "https://example.com")!, error: .constant(nil), isLoading: .constant(nil))
}
