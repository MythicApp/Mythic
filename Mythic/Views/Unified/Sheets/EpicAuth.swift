//
//  EpicAuth.swift
//  Mythic
//
// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

// TODO: make redundant
struct EpicAuthView: View {
    @Binding var isPresented: Bool
    @Binding var isSigninSuccessful: Bool

    @State private var authKey: String = .init()
    @State private var isSigninInitiated: Bool = false
    @State private var hasSigninLinkOpened: Bool = false
    @State private var isHelpPopoverPresented: Bool = false
    @State private var signinError: Error?

    func attemptSignIn() {
        guard !authKey.isEmpty else { return }
        withAnimation {
            isSigninInitiated = true
        }
        defer {
            withAnimation {
                isSigninInitiated = false
            }
        }
        Task {
            do {
                try await Legendary.signIn(authKey: authKey)
                isSigninSuccessful = true
                isPresented = false
            } catch {
                signinError = error
            }
        }
    }

    // MARK: - Body
    var body: some View {
        Text("Sign in to Epic Games")
            .font(.title)
            .task(priority: .userInitiated) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // reading delay
                    hasSigninLinkOpened = true
                    workspace.open(URL(string: "http://legendary.gl/epiclogin")!)
                }
            }

        Divider()

        Text("A link should open in your browser.")
        if hasSigninLinkOpened {
            Text("If the link didn't open, click on the button below to open it manually.")
            Button("Open Signin Link") {
                workspace.open(URL(string: "http://legendary.gl/epiclogin")!)
            }
            .disabled(isSigninInitiated)
        }

        Text("Enter the 'authorisationCode' from the JSON response in the field below.")

        HStack {
            SecureField("Enter authorisation key...", text: $authKey)
                .onSubmit {
                    attemptSignIn()
                }
                .frame(width: 350, alignment: .center)

            if isSigninInitiated {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Submit") {
                    attemptSignIn()
                }
                .buttonStyle(.borderedProminent)
            }
        }

        HStack {
            Spacer()

            Button {
                isHelpPopoverPresented.toggle()
            } label: {
                Image(systemName: "questionmark")
                    .controlSize(.small)
            }
            .clipShape(.circle)
            .popover(isPresented: $isHelpPopoverPresented) {
                Text("""
                    {
                        "redirectUrl": "https://localhost/launcher/authorized?code=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
                        "authorizationCode": \(Text(#" → "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" ←"#).foregroundStyle(.green)),
                        "exchangeCode": null,
                        "sid": null,
                        "ssoV2Enabled": true
                    }
                    """)
                .padding()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    EpicAuthView(
        isPresented: .constant(true),
        isSigninSuccessful: .constant(false)
    )
}
