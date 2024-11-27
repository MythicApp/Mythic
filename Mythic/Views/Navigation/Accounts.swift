//
//  Accounts.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/3/2024.
//
//  Tweaked by dxrkinfuser44 on 27/11/2024.
//

import SwiftUI
import SwordRPC

struct AccountsView: View {
    @State private var isSignOutConfirmationPresented: Bool = false
    @State private var isAuthViewPresented: Bool = false
    @State private var isHoveringOverDestructiveButton: Bool = false
    @State private var signedIn: Bool = false
    
    var body: some View {
        List {
            AccountRow(
                imageName: "EGFaceless",
                accountName: "Epic",
                accountStatus: signedIn ? "Signed in as \"\(Legendary.whoAmI())\"." : "Not signed in",
                isHovering: $isHoveringOverDestructiveButton,
                isSignedIn: signedIn,
                onButtonClick: {
                    if signedIn {
                        isSignOutConfirmationPresented = true
                    } else {
                        isAuthViewPresented = true
                    }
                }
            )
            .task { signedIn = Legendary.signedIn() }
            
            AccountRow(
                imageName: "Steam",
                accountName: "Steam",
                accountStatus: "Coming Soon",
                isHovering: $isHoveringOverDestructiveButton,
                isSignedIn: false,
                onButtonClick: {},
                isButtonDisabled: true
            )
        }
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
        .sheet(isPresented: $isAuthViewPresented, onDismiss: { signedIn = Legendary.signedIn() }) {
            AuthView(isPresented: $isAuthViewPresented)
        }
        .alert(isPresented: $isSignOutConfirmationPresented) {
            Alert(
                title: Text("Are you sure you want to sign out from Epic?"),
                message: Text("This will sign you out of the account \"\(Legendary.whoAmI())\"."),
                primaryButton: .destructive(Text("Sign Out")) {
                    Task {
                        try? await Legendary.command(arguments: ["auth", "--delete"], identifier: "signout")
                        signedIn = Legendary.signedIn()
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }
}

struct AccountRow: View {
    let imageName: String
    let accountName: String
    let accountStatus: String
    @Binding var isHovering: Bool
    let isSignedIn: Bool
    let onButtonClick: () -> Void
    var isButtonDisabled: Bool = false
    
    var body: some View {
        HStack {
            Image(imageName)
                .resizable()
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading) {
                Text(accountName)
                Text(accountStatus)
                    .font(.bold(.title3)())
            }
            
            Spacer()
            
            Button(action: onButtonClick) {
                Image(systemName: isSignedIn ? "person.slash" : "person")
                    .foregroundStyle(isHovering ? .red : .primary)
                    .padding(5)
            }
            .clipShape(Circle())
            .disabled(isButtonDisabled)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering && isSignedIn
                }
            }
        }
    }
}

#Preview {
    AccountsView()
}
