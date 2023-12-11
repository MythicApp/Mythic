//
//  PlayDefaultPrompt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/10/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
