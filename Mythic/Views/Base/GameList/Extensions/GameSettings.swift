//
//  GameSettings.swift // Name is not settings, settings is reserved for swift compiler or something
//  Mythic
//
//  Created by Esiayo Alegbe on 28/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import SwiftyJSON

extension GameListView {
    struct SettingsView: View {
        @Binding var isPresented: Bool
        public var game: Legendary.Game

        var body: some View { // TO IMPLEMENT LATER: IMPLEMENT REPAIR BUTTON IF IF NEEDS VERIFICATION IS TRUE IN INSTALLED.JSON
            VStack {
                Text(game.title)
                    .font(.title)

                Spacer()

                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Close")
                    }
                }
            }
            .padding()
            .fixedSize()
        }
    }
}

#Preview {
    GameListView.SettingsView(
        isPresented: .constant(true),
        game: .init(
            appName: "[appName]",
            title: "[title]"
        )
    )
}
