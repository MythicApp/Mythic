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
            VStack {
                Text(game)
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
    LibraryView()
}
