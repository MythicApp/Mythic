//
//  WebView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

import SwiftUI
import WebKit
import OSLog

struct WebView: NSViewRepresentable {
    @Binding var loadingError: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool

    var urlString: String

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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
            DispatchQueue.main.async { [self] in
                parent.log.error("\(error)")
                parent.loadingError = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            DispatchQueue.main.async { [self] in
                parent.canGoBack = webView.canGoBack
                parent.canGoForward = webView.canGoForward
                parent.isLoading = false
                parent.loadingError = false
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
            DispatchQueue.main.async { [self] in
                parent.isLoading = true
            }
        }
    }
}

#Preview {
    WebView(
        loadingError: .constant(false),
        canGoBack: .constant(false),
        canGoForward: .constant(false),
        isLoading: .constant(false),
        urlString: "https://example.com"
    )
}
