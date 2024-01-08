//
//  PlayDefaultPrompt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 15/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

extension GameListView {
    // MARK: - PlayDefaultView Struct
    /// An extension of the `GameListView` that defines the `PlayDefaultView` SwiftUI view for playing a game if defaults aren't set.
    struct PlayDefaultView: View {
        
        // MARK: - Bindings
        @Binding var isPresented: Bool
        public var game: Game
        @Binding var isGameListRefreshCalled: Bool
        
        // MARK: - Body View
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

// MARK: - Preview
#Preview {
    GameListView.PlayDefaultView(
        isPresented: .constant(true),
        game: Game(isLegendary: false, title: "Placeholder"),
        isGameListRefreshCalled: .constant(false)
    )
}
