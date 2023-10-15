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
        @Binding var game: Legendary.Game
        @Binding var isGameListRefreshCalled: Bool
        
        var body: some View {
            Text("")//Circle().foregroundColor(isAppInstalled(bundleIdentifier: "com.isaacmarovitz.Whisky") ? .green : .red)
        }
    }
}
