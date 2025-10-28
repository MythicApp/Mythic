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
    @State private var isSignOutConfirmationPresented: Bool = false
    @State private var epicSignOutStatusDidChange: Bool = false
    @State private var isHoveringOverDestructiveEpicButton: Bool = false
    // @State private var isEpicSigninFallbackAlertPresented: Bool = false
    @State private var isEpicSigninFallbackViewPresented: Bool = false
    @State private var isEpicSigninFallbackSuccessful: Bool = false
    @State private var epicSigninAttemptCount: Int = 0

    @State private var isHoveringOverDestructiveSteamButton: Bool = false

    // Spacer()s here are necessary
    var body: some View {
        VStack {
            HStack {
                // MARK: Epic Card
                // TODO: create AccountCard
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .overlay(alignment: .top) {
                        VStack {
                            Image("EGFaceless")
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 60)
                            
                            Spacer()
                            
                            VStack {
                                HStack {
                                    Text("Epic")
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(Legendary.signedIn ? "Signed in as \"\(Legendary.user ?? "Unknown")\"." : "Not signed in")
                                        .font(.bold(.title3)())
                                    Spacer()
                                }
                            }
                            
                            Button {
                                if Legendary.signedIn {
                                    isSignOutConfirmationPresented = true
                                } else {
                                    epicSigninAttemptCount += 1

                                    if epicSigninAttemptCount < 2 {
                                        epicWebAuthViewModel.showSignInWindow()
                                    } else {
                                        isEpicSigninFallbackViewPresented = true
                                    }
                                }
                            } label: {
                                Image(systemName: "person")
                                    .symbolVariant(Legendary.signedIn ? .slash : .none)
                                    .foregroundStyle(isHoveringOverDestructiveEpicButton ? .red : .primary)
                                    .padding(5)
                                
                            }
                            .clipShape(.circle)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isHoveringOverDestructiveEpicButton = (hovering && Legendary.signedIn)
                                }
                            }
                            /*
                            .onChange(of: epicWebAuthViewModel.isEpicSignInWindowVisible) { _, visible in
                                if !visible, !epicWebAuthViewModel.signInSuccess {
                                    isEpicSigninFallbackAlertPresented = true
                                }
                            }
                             // FIXME: SwiftUI doesn't like this alert, beats me.
                             .alert(isPresented: $isEpicSigninFallbackAlertPresented) {
                                 Alert(
                                     title: .init("Having trouble signing in?"),
                                     message: .init("""
                                     Try signing into your Epic Games account manually through a web browser and try again.
                                     If that doesn't work, you can try using the fallback method below.
                                     """),
                                     primaryButton: .default(.init("Try Fallback Method")) {
                                         isEpicSigninFallbackViewPresented = true
                                     },
                                     secondaryButton: .cancel()
                                 )
                             }
                             */
                            .sheet(isPresented: $isEpicSigninFallbackViewPresented) {
                                AuthView(
                                    isPresented: $isEpicSigninFallbackViewPresented,
                                    isSigninSuccessful: $isEpicSigninFallbackSuccessful
                                )
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .id(epicWebAuthViewModel.signInSuccess)
                    .id(isEpicSigninFallbackSuccessful)
                    .id(epicSignOutStatusDidChange)
                    .alert(isPresented: $isSignOutConfirmationPresented) {
                        Alert(
                            title: .init("Are you sure you want to sign out of Epic Games?"),
                            message: .init("This will sign you out of the account \"\(Legendary.user ?? "Unknown")\"."),
                            primaryButton: .destructive(.init("Sign Out")) {
                                Task(priority: .high) {
                                    try? await Legendary.signOut()
                                    epicSignOutStatusDidChange.toggle()
                                }
                            },
                            secondaryButton: .cancel(.init("Cancel"))
                        )
                    }

                // MARK: Steam Card
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .overlay(alignment: .top) {
                        VStack {
                            Image("Steam")
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 60)
                            
                            Spacer()
                            
                            VStack {
                                HStack {
                                    Text("Steam")
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Coming Soon")
                                        .font(.bold(.title3)())
                                    Spacer()
                                }
                            }
                            
                            Button {
                                //
                            } label: {
                                Image(systemName: /* signedIn ? "person.slash" : */ "person")
                                    .foregroundStyle(isHoveringOverDestructiveSteamButton ? .red : .primary)
                                    .padding(5)
                                
                            }
                            .clipShape(.circle)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isHoveringOverDestructiveSteamButton = (hovering && Legendary.signedIn)
                                }
                            }
                        }
                        .padding()
                    }
                    .disabled(true)
                
                Spacer() // push to top corner..
            }
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
            
            Spacer() // push to top corner..
        }
    }
}

#Preview {
    AccountsView()
}
