//
//  Accounts.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/3/2024.
//

import SwiftUI
import SwordRPC

struct AccountsView: View {
    var body: some View {
        NotImplementedView()
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

#Preview {
    AccountsView()
}
