//
//  EpicWebAuthView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/10/24.
//

import SwiftUI
import WebKit
import SwiftyJSON
import OSLog

struct EpicWebAuthView: View {
    @ObservedObject var viewModel: EpicWebAuthViewModel
    @State private var attemptingSignIn: Bool = false
    @State private var isSigninErrorPresented: Bool = false
    @State private var signInError: Error?
    @State private var authKey: String = .init()

    var body: some View {
        EpicInterceptorWebView { authKey = $0 }
            .blur(radius: attemptingSignIn ? 30 : 0)
            .onChange(of: authKey, { handleAuthKeyChange($1) })
            .onAppear {
                viewModel.webAuthViewPresented = true
                viewModel.signInSuccess = false
            }
            .onDisappear {
                authKey = .init()
                viewModel.webAuthViewPresented = false
            }
            .alert(isPresented: $isSigninErrorPresented) {
                .init(
                    title: Text("Unable to sign in to Epic Games."),
                    message: Text(signInError?.localizedDescription ?? "An unknown error occurred."),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .cancel()
                )
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if attemptingSignIn {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
    }

    private func handleAuthKeyChange(_ newAuthKey: String) {
        guard !newAuthKey.isEmpty else { return }
        attemptingSignIn = true // no animation

        Task {
            do {
                try await Legendary.signIn(authKey: newAuthKey)
                viewModel.signInSuccess = true
                viewModel.closeSignInWindow()
            } catch {
                signInError = error
                isSigninErrorPresented = true
            }

            withAnimation { attemptingSignIn = false }
        }
    }
}

final class EpicWebAuthViewModel: ObservableObject {
    public static let shared = EpicWebAuthViewModel()
    @Published var webAuthViewPresented = false
    @Published var signInSuccess = false
    
    // Keep a strong reference to the sign-in window
    private var epicSignInWindow: NSWindow?

    private init() {}

    @MainActor
    func showSignInWindow() {
        guard epicSignInWindow == nil else {
            Logger.app.warning("Epic sign-in window already open")
            return
        }

        guard !Legendary.signedIn else {
            Logger.app.warning("User is already signed in, skipping sign-in window")
            return
        }

        let window = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.identifier = .init("epic-signin")
        window.contentView = NSHostingView(rootView: EpicWebAuthView(viewModel: self))
        window.titlebarAndTextHidden = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        sharedApp.activate(ignoringOtherApps: true)

        epicSignInWindow = window
        webAuthViewPresented = true
    }

    @MainActor
    func closeSignInWindow() {
        epicSignInWindow?.close()
        epicSignInWindow = nil
        webAuthViewPresented = false
    }
}

fileprivate struct EpicInterceptorWebView: NSViewRepresentable {
    let completion: (String) -> Void

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: EpicInterceptorWebView

        init(parent: EpicInterceptorWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.innerText") { result, error in
                guard
                    error == nil,
                    let content = result as? String,
                    let data = content.data(using: .utf8),
                    let json = try? JSON(data: data),
                    let code = json["authorizationCode"].string
                else { return }

                self.parent.completion(code)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://legendary.gl/epiclogin")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.stopLoading()
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
    }
}
