//
//  AccountsView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/3/2024.
//

// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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
                    signedInUser: .constant(Legendary.user),
                    image: Image("EGFaceless"),
                    source: .epic,
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
        var source: Game.Source
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
                    Text(source.rawValue)
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
                        /* ☹️☹️ swiftui will not let me do this, stupid hierarchy stupid swiftui rules
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
