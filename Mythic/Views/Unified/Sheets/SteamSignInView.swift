//
//  SteamSignInView.swift
//  Mythic
//
//  Created by Brunelli Cupello on 21/8/2026.
//

// Copyright © 2023-2026 vapidinfinity

import SwiftUI
import OSLog

/**
 Signs in to Steam through SteamCMD.

 There is no web flow here on purpose. Steam's OpenID login yields a SteamID and *no* SteamCMD
 credential, so it cannot download anything — the credential SteamCMD caches itself is the thing that
 makes the rest of the storefront work.
 */
struct SteamSignInView: View {
    @Binding var isPresented: Bool

    @State private var username: String = .init()
    @State private var password: String = .init()
    @State private var steamGuardCode: String = .init()

    /// Revealed only once Steam has actually asked for a code, so the form starts minimal.
    @State private var isSteamGuardCodeRequired: Bool = false

    // Signing in *is* running SteamCMD, so there is no meaningful "account but no backend" state. When
    // the backend is missing this sheet installs it first rather than sending the user to Settings to
    // find it themselves.
    @State private var isSteamCMDInstalled: Bool = true
    @State private var isRosettaInstalled: Bool = true
    @State private var isInstallingSteamCMD: Bool = false
    @State private var isSteamCMDInstallSuccessful: Bool?
    @State private var steamCMDInstallError: Error?

    @State private var isSigningIn: Bool = false
    @State private var isAwaitingMobileConfirmation: Bool = false
    @State private var signInError: Error?

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
        && !password.isEmpty
        && (!isSteamGuardCodeRequired || !steamGuardCode.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        VStack {
            HStack {
                Image("Steam")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading) {
                    Text("Sign in to Steam")
                        .font(.title2)
                        .bold()
                    Text(!isSteamCMDInstalled
                         ? String(localized: "One quick setup step first.")
                         : isAwaitingMobileConfirmation
                           ? String(localized: "Waiting for you to approve this in the Steam Mobile App.")
                           : String(localized: "Mythic signs in through SteamCMD, Valve's own command-line client."))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                }

                Spacer()
            }
            .padding([.horizontal, .top])

            Form {
                if isSteamCMDInstalled {
                    Section {
                        TextField("Account name", text: $username)
                            .textContentType(.username)
                            .disabled(isSigningIn)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .disabled(isSigningIn)
                            .onSubmit(signIn)
                    } footer: {
                        Text("Your password goes straight to SteamCMD and is never written to disk by Mythic.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    // Said up front, not just once it goes wrong: accounts on the mobile authenticator
                    // get a push rather than a typed code, and Steam gives up waiting fairly quickly.
                    // A user staring at a spinner has no way to guess their phone is the missing step.
                    if isAwaitingMobileConfirmation {
                        // Steam really is waiting on the phone right now, and it gives up after about a
                        // minute. This is the one moment the user has to act, so it gets the loudest
                        // treatment in the sheet rather than a footnote.
                        Section {
                            HStack(alignment: .top) {
                                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.tint)
                                    .padding(.trailing, 4)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Approve this sign-in on your phone")
                                        .font(.headline)

                                    Text("Steam sent a confirmation to the Steam Mobile App. Open it and tap Approve.")
                                        .fixedSize(horizontal: false, vertical: true)

                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.small)
                                        Text("Steam stops waiting after about a minute.")
                                            .foregroundStyle(.secondary)
                                            .font(.footnote)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else if isSigningIn {
                        Section {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Signing in…")
                            }
                        }
                    } else {
                        Section {
                            Label("If your account uses the Steam Mobile Authenticator, keep your phone handy — Steam will ask you to approve this there.",
                                  systemImage: "iphone.and.arrow.right.inward")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if isSteamGuardCodeRequired {
                        Section {
                            TextField("Steam Guard code", text: $steamGuardCode)
                                .disabled(isSigningIn)
                                .onSubmit(signIn)
                        } footer: {
                            Text("From your authenticator app, or the email Steam just sent you.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SteamCMD isn't installed yet")
                                    .bold()
                                Text("It's a small download (about 3 MB) from Valve. Mythic needs it to sign in and to download your games.")
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                        }

                        OperationButton(
                            "Install SteamCMD",
                            systemImage: "arrow.down.circle",
                            operating: $isInstallingSteamCMD,
                            successful: $isSteamCMDInstallSuccessful
                        ) {
                            await installSteamCMD()
                        }
                        // SteamCMD ships as an x86_64 Mach-O binary only.
                        .disabled(!isRosettaInstalled)
                    } header: {
                        Text("Step 1 of 2")
                    } footer: {
                        if !isRosettaInstalled {
                            Label("SteamCMD is an Intel binary and needs Rosetta 2, which isn't installed.",
                                  systemImage: "exclamationmark.triangle")
                            .symbolVariant(.fill)
                            .font(.footnote)
                        } else {
                            Text("Signing in comes next.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { isPresented = false }
                    .disabled(isSigningIn)
                    .disabled(isInstallingSteamCMD)

                Spacer()

                if isSteamCMDInstalled {
                    OperationButton("Sign In",
                                    operating: $isSigningIn,
                                    successful: .constant(nil)) {
                        await performSignIn()
                    }
                    .disabled(!canSubmit)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding([.horizontal, .bottom])
        }
        .task {
            // Both touch the filesystem (Rosetta.exists spawns pgrep), so they are resolved once here
            // rather than re-evaluated on every render of `body`.
            isSteamCMDInstalled = SteamCMD.isInstalled
            isRosettaInstalled = Rosetta.exists
        }
        .alert("Unable to install SteamCMD.",
               isPresented: .init(get: { steamCMDInstallError != nil },
                                  set: { if !$0 { steamCMDInstallError = nil } }),
               presenting: steamCMDInstallError) { _ in
            Button("OK") { steamCMDInstallError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert("Unable to sign in to Steam.",
               isPresented: .init(get: { signInError != nil },
                                  set: { if !$0 { signInError = nil } }),
               presenting: signInError) { _ in
            Button("OK") { signInError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func installSteamCMD() async {
        do {
            try await SteamCMD.install()
            isSteamCMDInstallSuccessful = true
        } catch {
            Logger.app.error("SteamCMD installation failed: \(error.localizedDescription)")
            isSteamCMDInstallSuccessful = false
            steamCMDInstallError = error
        }

        // Re-read rather than trusting the outcome flag: `isInstalled` is the filesystem's opinion.
        isSteamCMDInstalled = SteamCMD.isInstalled
    }

    private func signIn() {
        guard canSubmit, !isSigningIn else { return }
        Task { await performSignIn() }
    }

    private func performSignIn() async {
        isAwaitingMobileConfirmation = false
        defer { isAwaitingMobileConfirmation = false }

        do {
            try await Steam.signIn(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password,
                steamGuardCode: isSteamGuardCodeRequired
                    ? steamGuardCode.trimmingCharacters(in: .whitespaces)
                    : nil,
                onStatus: { status in
                    // Reported from SteamCMD's output stream, off the main actor.
                    Task { @MainActor in
                        isAwaitingMobileConfirmation = (status == .awaitingMobileConfirmation)
                    }
                }
            )

            password = .init()
            isPresented = false
        } catch SteamCMD.Failure.twoFactorRequired {
            // Not surfaced as an error: it is a step, not a failure. Reveal the field and let them retry.
            isSteamGuardCodeRequired = true
        } catch {
            Logger.app.error("Steam sign-in failed: \(error.localizedDescription)")
            signInError = error
        }
    }
}

#Preview {
    SteamSignInView(isPresented: .constant(true))
        .frame(width: 420)
}
