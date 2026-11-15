//
//  SteamWebAuthView.swift
//  Mythic
//

import AppKit
import Security
import SwiftUI
import WebKit

struct SteamWebAuthView: View {
    @Binding var isPresented: Bool
    let onSignedIn: (String) -> Void

    @State private var nonce: String?
    @State private var error: Error?
    @State private var isVerifying = false

    var body: some View {
        Group {
            if let nonce {
                VStack(spacing: 0) {
                    SteamAuthWebView(
                        nonce: nonce,
                        isPresented: $isPresented,
                        isVerifying: $isVerifying,
                        onSignedIn: onSignedIn,
                        onError: { error = $0 }
                    )
                    if let error {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
            } else if let error {
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if isVerifying {
                ProgressView(String(localized: "Verifying Steam sign-in..."))
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .onAppear {
            guard nonce == nil, error == nil else { return }
            do {
                nonce = try Self.makeNonce()
            } catch {
                self.error = error
            }
        }
    }

    private static func makeNonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
        }
        guard status == errSecSuccess else {
            throw NonceGenerationError()
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private struct NonceGenerationError: LocalizedError {
        var errorDescription: String? {
            String(localized: "Unable to securely start Steam sign-in.")
        }
    }
}

private struct SteamAuthWebView: NSViewRepresentable {
    let nonce: String
    @Binding var isPresented: Bool
    @Binding var isVerifying: Bool
    let onSignedIn: (String) -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        let loginURL = SteamAuth.makeLoginURL(nonce: nonce)
        guard loginURL.scheme?.lowercased() == "https",
              loginURL.host?.lowercased() == "steamcommunity.com" else {
            context.coordinator.parent.onError(SteamLoginURLError())
            return webView
        }
        webView.load(URLRequest(url: loginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.stopLoading()
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: SteamAuthWebView
        private var hasHandledCallback = false

        init(parent: SteamAuthWebView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(policy(for: navigationAction, in: webView))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            // the sign-in window never downloads anything
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // never open new windows; load permitted Steam pages in place, everything else is handled by `policy`.
            if policy(for: navigationAction, in: webView) == .allow {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func policy(for action: WKNavigationAction, in webView: WKWebView) -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            if SteamAuth.isCallback(url) {
                verifyCallback(url)
                return .cancel
            }

            guard url.scheme?.lowercased() == "https" else { return .cancel }
            let isMainFrame = action.targetFrame?.isMainFrame ?? true
            guard isMainFrame else { return .allow }

            let host = url.host?.lowercased() ?? ""
            guard isAllowedSteamHost(host),
                  url.port == nil || url.port == 443,
                  url.user == nil,
                  url.password == nil else {
                // Only hand a link to the browser when the user clicked it; never for script-initiated navigations or
                // redirects, and never with embedded credentials.
                if action.navigationType == .linkActivated, url.user == nil, url.password == nil {
                    NSWorkspace.shared.open(url)
                }
                return .cancel
            }
            return .allow
        }

        private func isAllowedSteamHost(_ host: String) -> Bool {
            ["steamcommunity.com", "steampowered.com"].contains { domain in
                host == domain || host.hasSuffix("." + domain)
            }
        }

        private func verifyCallback(_ url: URL) {
            guard !hasHandledCallback else { return }
            hasHandledCallback = true
            parent.isVerifying = true

            Task { @MainActor in
                defer { parent.isVerifying = false }
                do {
                    let steamID = try await SteamAuth.verify(callbackURL: url, expectedNonce: parent.nonce)
                    try SteamAuth.completeSignIn(steamID: steamID)
                    parent.onSignedIn(steamID)
                    parent.isPresented = false
                } catch {
                    hasHandledCallback = false // allow the user to retry sign-in
                    parent.onError(error)
                }
            }
        }
    }

    private struct SteamLoginURLError: LocalizedError {
        var errorDescription: String? {
            String(localized: "Unable to securely open Steam sign-in.")
        }
    }
}
