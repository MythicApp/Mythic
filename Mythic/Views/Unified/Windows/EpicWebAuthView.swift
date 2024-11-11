//
//  EpicWebAuthView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/10/24.
//

import SwiftUI
import WebKit
import SwiftyJSON
import OSLog

struct EpicWebAuthView: View {
    @ObservedObject var viewModel = EpicWebAuthViewModel.shared

    @State private var attemptingSignIn: Bool = false
    @State private var isSigninErrorPresented: Bool = false
    @State private var signInError: Error?

    @State private var authKey: String = .init()

    var body: some View {
        EpicInterceptorWebView(completion: { authKey = $0 })
            .blur(radius: attemptingSignIn ? 30 : 0)
            .onChange(of: authKey) {
                guard !$1.isEmpty else { return }

                Task {
                    do {
                        attemptingSignIn = true
                        try await Legendary.signIn(authKey: authKey)
                        viewModel.closeEpicSignInWindow()
                    } catch {
                        self.signInError = error
                        isSigninErrorPresented = true
                    }

                    withAnimation {
                        attemptingSignIn = false
                    }
                }
            }
            .onDisappear {
                authKey = .init()
            }
            .alert(isPresented: $isSigninErrorPresented) {
                .init(
                    title: .init("Unable to sign in to Epic."),
                    message: .init(signInError?.localizedDescription ?? "Unknown Error."),
                    primaryButton: .default(.init("OK")),
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
}

final class EpicWebAuthViewModel: ObservableObject {
    public static let shared: EpicWebAuthViewModel = .init()
    private init() {}

    @MainActor
    func showEpicSignInWindow() {
        guard sharedApp.window(withID: "epic-signin") == nil else {
            Logger.app.warning("Epic sign-in window already open")
            return
        }

        let hostingView: NSHostingView = .init(rootView: EpicWebAuthView())

        let window = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = .init("epic-signin")
        window.contentView = hostingView

        window.titlebarAndTextHidden = true
        window.center()
        window.makeKeyAndOrderFront(nil)

        sharedApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func closeEpicSignInWindow() {
        // FIXME: .close() causes stupid crash for unknown reason
        sharedApp.window(withID: "epic-signin")?.orderOut(nil)
    }
}

fileprivate struct EpicInterceptorWebView: NSViewRepresentable {
    var completion: (String) -> Void

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EpicInterceptorWebView
        @State private var isLoading: Bool = false // FIXME: pointless

        init(parent: EpicInterceptorWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false

            webView.evaluateJavaScript("document.body.innerText") { result, error in
                guard
                    error == nil,
                    let content = result as? String,
                    let data = content.data(using: .utf8),
                    let json: JSON = try? .init(data: data)
                else {
                    return
                }

                if let code = json["authorizationCode"].string {
                    self.parent.completion(code)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()  // don't persist user data

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(URLRequest(url: .init(string: "https://legendary.gl/epiclogin")!))
    }
}
