//
//  WebView.swift
//  Mythic
//
//  Created by Josh on 11/16/24.
//

import SwiftUI
import Combine
import WebKit

public struct WebView2: View {
    @Binding private var canGoBack: Bool
    @Binding private var canGoForward: Bool
    @Binding private var isLoading: Bool
    @Binding private var url: URL?
    @Binding private var view: WKWebView?
    private var initWebViewConfig: (@MainActor (_ webView: WKWebViewConfiguration) -> Void)?
    private var initWebView: (@MainActor (_ webView: WKWebView) -> Void)?
    private var handleNavigationAction: (@MainActor (_ webView: WKWebView, _ policy: WKNavigationAction)
                                                        -> NavigationPolicy)?

    @State private var error: Error?
    @State private var cancelables: Set<NSKeyValueObservation> = .init()

    public enum NavigationPolicy: Int, CaseIterable, Identifiable, Hashable, Sendable {
        public var id: Int {
            rawValue
        }

        case allow
        case cancel
        case openExternal
    }

    public init(canGoBack: Binding<Bool> = .constant(false),
                canGoForward: Binding<Bool> = .constant(false),
                isLoading: Binding<Bool> = .constant(false),
                url: Binding<URL?> = .constant(nil),
                view: (Binding<WKWebView?>)? = nil,
                initWebView: (@MainActor (_ webView: WKWebView) -> Void)? = nil,
                initWebViewConfig: (@MainActor (_ webView: WKWebViewConfiguration) -> Void)? = nil,
                handleNavigationAction: (@MainActor (_ webView: WKWebView, _ policy: WKNavigationAction)
                                         -> NavigationPolicy)? = nil) {
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._isLoading = isLoading
        self._url = url
        if let view = view {
            self._view = view
        } else {
            self._view = State.init(initialValue: nil).projectedValue
        }
        self.initWebView = initWebView
        self.initWebViewConfig = initWebViewConfig
        self.handleNavigationAction = handleNavigationAction
    }

    private class WebViewCordinator: NSObject, WKNavigationDelegate {
        private let onCanGoBackChange: (Bool) -> Void
        private let onCanGoForwardChange: (Bool) -> Void
        private let onLoadingChange: (Bool) -> Void
        private let onURLChange: (URL?) -> Void
        private let handleNavigationAction: ((_ webView: WKWebView, _ policy: WKNavigationAction)
                                             -> NavigationPolicy)?
        private let onNavigationError: (Error?) -> Void

        init(onCanGoBackChange: @escaping (Bool) -> Void,
             onCanGoForwardChange: @escaping (Bool) -> Void,
             onLoadingChange: @escaping (Bool) -> Void,
             onURLChange: @escaping (URL?) -> Void,
             handleNavigationAction: ((_ webView: WKWebView, _ policy: WKNavigationAction)
                                      -> NavigationPolicy)?,
             onNavigationError: @escaping (Error?) -> Void) {
            self.onCanGoBackChange = onCanGoBackChange
            self.onCanGoForwardChange = onCanGoForwardChange
            self.onLoadingChange = onLoadingChange
            self.onURLChange = onURLChange
            self.handleNavigationAction = handleNavigationAction
            self.onNavigationError = onNavigationError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
            onLoadingChange(true)
            onCanGoBackChange(webView.canGoBack)
            onCanGoForwardChange(webView.canGoForward)
            onNavigationError(nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            onLoadingChange(false)
            onCanGoBackChange(webView.canGoBack)
            onCanGoForwardChange(webView.canGoForward)
            onNavigationError(nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
            onLoadingChange(false)
            onCanGoBackChange(webView.canGoBack)
            onCanGoForwardChange(webView.canGoForward)
            onNavigationError(error)
        }

        private func handlePageNavigation(
            with webView: WKWebView, policy: WKNavigationAction,
            action: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let handleNavigationAction = handleNavigationAction else {
                action(.allow)
                return
            }

            let result = handleNavigationAction(webView, policy)

            switch result {
            case .allow:
                action(.allow)
            case .cancel:
                action(.cancel)
            case .openExternal:
                action(.cancel)
                if let url = policy.request.url {
                    NSWorkspace.shared.open(url)
                }
            }
        }

#if compiler(>=6)
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @MainActor @escaping (WKNavigationActionPolicy) -> Void
        ) {
            handlePageNavigation(
                with: webView, policy: navigationAction,
                action: { result in
                    decisionHandler(result)
                })
        }
#else
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {

            handlePageNavigation(
                with: webView, policy: navigationAction,
                action: { result in
                    decisionHandler(result)
                })
        }
#endif
    }

    private struct WebView: NSViewRepresentable {
        private let coordinator: WebViewCordinator
        private let initWebViewConfig: ((_ webView: WKWebViewConfiguration) -> Void)?
        private let initWebView: ((_ webView: WKWebView) -> Void)?

        init(coordinator: WebViewCordinator,
             initWebViewConfig: ((_ webView: WKWebViewConfiguration) -> Void)?,
             initWebView: ((_ webView: WKWebView) -> Void)?) {
            self.coordinator = coordinator
            self.initWebViewConfig = initWebViewConfig
            self.initWebView = initWebView
        }

        func makeNSView(context: Context) -> WKWebView {
            let config = WKWebViewConfiguration()
            initWebViewConfig?(config)

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = coordinator
            webView.setValue(false, forKey: "drawsBackground")

            initWebView?(webView)

            return webView
        }

        func updateNSView(_ nsView: WKWebView, context: Context) {
            nsView.navigationDelegate = coordinator
        }

        func makeCoordinator() -> WebViewCordinator {
            coordinator
        }

        static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
            nsView.stopLoading()
        }
    }

    public var body: some View {
        WebView(
            coordinator: WebViewCordinator(
            onCanGoBackChange: { canGoBack = $0 },
            onCanGoForwardChange: { canGoForward = $0 },
            onLoadingChange: { isLoading = $0 },
            onURLChange: { url = $0 },
            handleNavigationAction: handleNavigationAction,
            onNavigationError: { error in
                DispatchQueue.main.async {
                    withAnimation {
                        self.error = error
                    }
                }
            }
            ), initWebViewConfig: initWebViewConfig, initWebView: { view in
                DispatchQueue.main.async {
                    self.view = view
                    initWebView?(view)
                }
            })
        .overlay {
            if let error = error {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "pc")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                    Text(String(format: String(localized: "webView.error"), error.localizedDescription))
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .opacity(0.6)
                    Button {
                        withAnimation {
                            self.error = nil
                        }
                        if let url = url, let view = view {
                            view.load(URLRequest(url: url))
                        }
                    } label: {
                        Label("webView.retry", systemImage: "arrow.clockwise")
                            .padding(6)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(.ultraThinMaterial)
            }
        }
        .onChange(of: url) {
            guard let view = view else { return }
            if let url = url, view.url != url {
                view.load(URLRequest(url: url))
            }
        }
        .onChange(of: view) {
            guard let view = view else { return }

            cancelables.removeAll()

            cancelables.insert(view.observe(\.url) { view, _ in
                url = view.url
            })
            cancelables.insert(view.observe(\.canGoBack) { view, _ in
                canGoBack = view.canGoBack
            })
            cancelables.insert(view.observe(\.canGoForward) { view, _ in
                canGoForward = view.canGoForward
            })

            if let url = url, view.url != url {
                view.load(URLRequest(url: url))
            }
        }
    }
}
