//
//  AccountsView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/3/2024.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import SwordRPC

struct AccountsView: View {
    @ObservedObject private var epicWebAuthViewModel: EpicWebAuthViewModel = .shared

    @State private var isEpicSignOutConfirmationAlertPresented: Bool = false
    @State private var epicSignOutError: Error?
    @State private var isEpicSignOutErrorAlertPresented: Bool = false
    @State private var isEpicAccountCardRefreshed = false

    var body: some View {
        ScrollView {
            HStack {
                AccountCard(
                    signedInUser: .constant(try? Legendary.retrieveUser()),
                    image: Image("EGFaceless"),
                    storefront: .epicGames,
                    signInAction: {
                        Task { @MainActor in
                            epicWebAuthViewModel.showSignInWindow()
                        }
                    },
                    signOutAction: {
                        isEpicSignOutConfirmationAlertPresented = true
                    }
                )
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quinary)
                )
                .alert(
                    "Are you sure you want to sign out of Epic Games?",
                    isPresented: $isEpicSignOutConfirmationAlertPresented
                ) {
                    Button(role: .destructive) {
                        Task {
                            do {
                                try await Legendary.signOut()
                                isEpicAccountCardRefreshed.toggle()
                                // FIXME: no way to propogate error
                                // below is the code to do it
                                /*
                                .alert(
                                    "Unable to sign out of Epic Games.",
                                    isPresented: $isEpicSignOutErrorAlertPresented,
                                    presenting: epicSignOutError
                                ) { _ in
                                    Button(role: .close) {

                                    } label: {
                                        Text("OK")
                                    }
                                } message: { error in
                                    Text(error.localizedDescription)
                                }
                                */
                            } catch {
                                epicSignOutError = error
                                isEpicSignOutErrorAlertPresented = true
                            }
                        }
                    } label: {
                        Text("Sign Out")
                    }
                }
                .id(isEpicAccountCardRefreshed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .navigationTitle("Accounts")
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Currently in the accounts section."
                presence.state = "Checking out all their accounts"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"

                return presence
            }())
        }
    }
}

extension AccountsView {
    struct AccountCard: View {
        @Binding var signedInUser: String?

        var image: Image
        var storefront: Game.Storefront
        var signInAction: () -> Void
        var signOutAction: () -> Void

        @State private var isHoveringOverSignOutButton: Bool = false
        // @State private var isSignOutConfirmationAlertPresented: Bool = false

        var body: some View {
            HStack {
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 60)

                VStack(alignment: .leading) {
                    Text(storefront.description)
                        .font(.title.bold())

                    Text(signedInUser != nil ? "Signed in as \"\(signedInUser ?? "Unknown")\"" : "Not signed in")
                }

                Group {
                    if signedInUser != nil {
                        Button("Sign Out", systemImage: "person.slash", action: signOutAction)
                            .onHover { hovering in
                                withAnimation {
                                    isHoveringOverSignOutButton = hovering
                                }
                            }
                            .conditionalTransform(if: isHoveringOverSignOutButton) { view in
                                view
                                    .foregroundStyle(.red)
                            }
                        /* FIXME: ☹️☹️ swiftui will not let me do this, stupid hierarchy stupid swiftui rules
                         FIXME: for now, it's called in AccountsView
                            .alert(
                                "Are you sure you want to sign out of Epic Games?",
                                isPresented: $isEpicSignOutConfirmationAlertPresented
                            ) {
                                Button(role: .destructive) {
                                    signOutAction()
                                } label: {
                                    Text("Sign Out")
                                }
                            }
                         */
                    } else {
                        Button("Sign In", systemImage: "person", action: signInAction)
                    }
                }
                .clipShape(.capsule)
                .padding(.leading)
            }
        }
    }
}

#Preview {
    AccountsView()
}
