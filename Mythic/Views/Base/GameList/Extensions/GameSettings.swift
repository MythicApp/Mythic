//
//  GameSettings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 28/9/2023.
//

import SwiftUI
import SwiftyJSON

extension GameListView {
    struct SettingsView: View {
        @Binding var isPresented: Bool
        @Binding var game: String
        
        var body: some View {
            let installed_game = try! JSON(
                data: Legendary.command(args: ["list-installed","--json"]).stdout.data
            )
            
            VStack {
                Text(game)
                    .font(.title)
                
                Spacer()
                
                HStack {
                    Button(action: {
                        isPresented.toggle()
                    }) {
                        Text("Close")
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    LibraryView()
}
