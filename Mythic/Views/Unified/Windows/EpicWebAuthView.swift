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
    @ObservedObject var gameListViewModel: GameListVM = .shared
    @AppStorage("epicGamesWebDataStoreIdentifierString") var webDataStoreIdentifierString: String = UUID().uuidString

    @State private var isBlurred: Bool = false
    @State private var isWorking: Bool = false
    @State private var isSigninErrorPresented: Bool = false
    @State private var signInError: Error?
    @State private var authKey: String = .init()

    var body: some View {
        EpicInterceptorWebView(viewModel: viewModel, isWebAuthViewBlurred: $isBlurred, completion: { authKey = $0 })
            .blur(radius: (isBlurred || isWorking) ? 30 : 0)
            .onChange(of: authKey, { handleAuthKeyChange($1) })
            .onAppear {
                webDataStoreIdentifierString = UUID().uuidString
                viewModel.signInSuccess = false
                gameListViewModel.refresh()
            }
            .onDisappear {
                authKey = .init()
                gameListViewModel.refresh()
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
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
    }

    private func handleAuthKeyChange(_ newAuthKey: String) {
        guard !newAuthKey.isEmpty else { return }
        isWorking = true // no animation

        Task {
            do {
                try await Legendary.signIn(authKey: newAuthKey)
                viewModel.signInSuccess = true
                viewModel.closeSignInWindow()

                gameListViewModel.refresh()
            } catch {
                signInError = error
                isSigninErrorPresented = true
            }

            withAnimation { isWorking = false }
        }
    }
}

final class EpicWebAuthViewModel: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = EpicWebAuthViewModel()
    @Published var signInSuccess = false

    // FIXME: nonfunctional
    @Published var isEpicSignInWindowVisible: Bool = false

    // Keep a strong reference to the sign-in window
    private var epicSignInWindow: NSWindow?

    private override init() {
        super.init()
    }

    @MainActor
    func showSignInWindow(reloadHostingView: Bool = true) {
        if let window = epicSignInWindow {
            if reloadHostingView {
                window.contentView = NSHostingView(rootView: EpicWebAuthView(viewModel: self))
            }
            window.makeKeyAndOrderFront(nil)
            // Update visibility status
            isEpicSignInWindowVisible = window.isVisible
            return
        }

        guard !Legendary.signedIn else {
            Logger.app.warning("User is already signed in, skipping sign-in window")
            return
        }

        epicSignInWindow = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        epicSignInWindow?.identifier = .init("epic-signin")
        epicSignInWindow?.contentView = NSHostingView(rootView: EpicWebAuthView(viewModel: self))
        epicSignInWindow?.titlebarAndTextHidden = true
        epicSignInWindow?.center()
        epicSignInWindow?.makeKeyAndOrderFront(nil)
        epicSignInWindow?.isReleasedWhenClosed = false
        epicSignInWindow?.delegate = self
        isEpicSignInWindowVisible = epicSignInWindow?.isVisible ?? false

        sharedApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func invokeSignInError(
        errorMessage: String = Legendary.SignInError().localizedDescription,
        errorDescription: String
    ) {
        guard let window = epicSignInWindow, window.isVisible else {
            Logger.app.warning("Sign-in window isn't visible, skipping error alert")
            return
        }

        let error = NSAlert()
        error.messageText = errorMessage
        error.informativeText = errorDescription
        error.addButton(withTitle: "Close")

        error.beginSheetModal(for: window) { [self] response in
            switch response {
            case .alertFirstButtonReturn:
                fallthrough
            default:
                closeSignInWindow()
                break
            }
        }
    }

    @MainActor
    func closeSignInWindow() {
        epicSignInWindow?.orderOut(nil)
        isEpicSignInWindowVisible = false
        epicSignInWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        closeSignInWindow()
    }
}

fileprivate struct EpicInterceptorWebView: NSViewRepresentable {
    @ObservedObject var viewModel: EpicWebAuthViewModel
    @Binding var isWebAuthViewBlurred: Bool
    @AppStorage("epicGamesWebDataStoreIdentifierString") var webDataStoreIdentifierString: String = UUID().uuidString

    let completion: (String) -> Void

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: EpicInterceptorWebView

        init(parent: EpicInterceptorWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView,
                         createWebViewWith configuration: WKWebViewConfiguration,
                         for navigationAction: WKNavigationAction,
                         windowFeatures: WKWindowFeatures) -> WKWebView? {
                if navigationAction.targetFrame == nil {
                    webView.load(navigationAction.request)
                }
                return nil
            }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.innerText") { result, error in
                guard error == nil else {
                    self.parent.isWebAuthViewBlurred = true // no animation

                    self.parent.viewModel.invokeSignInError(
                        errorMessage: "Error reading webpage.",
                        errorDescription: error?.localizedDescription ?? "Unknown Error."
                    )

                    withAnimation { self.parent.isWebAuthViewBlurred = false }
                    return
                }

                guard
                    let content = result as? String,
                    let data = content.data(using: .utf8),
                    let json = try? JSON(data: data)
                else {
                    return
                }

                if let code = json["authorizationCode"].string {
                    self.parent.completion(code)
                } else if let errorCode = json["errorCode"].string,
                          var error = json["message"].string {
                    self.parent.isWebAuthViewBlurred = true // no animation

                    if errorCode == "errors.com.epicgames.oauth.corrective_action_required" {
                        error = "Please visit https://www.epicgames.com/id/login/correction on a normal web browser, and then try signing in through Mythic again."
                    }

                    self.parent.viewModel.invokeSignInError(
                        errorMessage: Legendary.SignInError().localizedDescription,
                        errorDescription: error
                    )

                    withAnimation { self.parent.isWebAuthViewBlurred = false }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        if let datastoreUUID: UUID = .init(uuidString: webDataStoreIdentifierString) {
            config.websiteDataStore = .init(forIdentifier: datastoreUUID)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
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
