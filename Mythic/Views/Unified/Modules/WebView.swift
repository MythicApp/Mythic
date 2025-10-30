//
//  WebView.swift
//  Mythic
//
// Copyright © 2023-2025 vapidinfinity

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
