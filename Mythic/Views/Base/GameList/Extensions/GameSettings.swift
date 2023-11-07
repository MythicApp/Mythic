//
//  GameSettings.swift // Name is not settings, settings is reserved for swift compiler or something
//  Mythic
//
//  Created by Esiayo Alegbe on 28/9/2023.
//

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
                    Button(action: {
                        isPresented = false
                    }) {
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
