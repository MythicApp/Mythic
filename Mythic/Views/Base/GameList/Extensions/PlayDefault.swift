//
//  PlayDefaultPrompt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/10/2023.
//

import SwiftUI

extension GameListView {
    struct PlayDefaultView: View {
        @Binding var isPresented: Bool
        public var game: Legendary.Game
        @Binding var isGameListRefreshCalled: Bool

        var body: some View {
            HStack {
                if isAppInstalled(bundleIdentifier: "com.isaacmarovitz.Whisky") {
                    Circle().foregroundColor(.green)
                    Text("Whisky installed!")
                } else {
                    Circle().foregroundColor(.red)
                    Text("Whisky is not installed!")
                }
            }
            .padding()
        }
    }
}

#Preview {
    GameListView.PlayDefaultView(
        isPresented: .constant(true),
        game: .init(
            appName: "[appName]",
            title: "[title]"
        ),
        isGameListRefreshCalled: .constant(false)
    )
}
