//
//  WebView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
