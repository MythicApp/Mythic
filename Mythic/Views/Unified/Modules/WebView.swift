//
//  WebView.swift
//  Mythic
//
// MARK: - Copyright
// Copyright © 2024 vapidinfinity

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
    var datastore: WKWebsiteDataStore = .default()

    @Binding var error: Error?
    var canGoBack: Bool?
    var canGoForward: Bool?
    
    let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "WebView"
    )
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = datastore

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != self.url {
            let request = URLRequest(url: self.url)
            nsView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
            parent.log.error("\(error.localizedDescription)")
            parent.error = error
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
    }
}

// MARK: - Preview
#Preview {
    WebView(url: .init(string: "https://example.com")!, error: .constant(nil))
}
