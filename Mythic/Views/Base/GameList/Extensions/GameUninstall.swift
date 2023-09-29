//
//  GameUninstall.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

extension GameListView {
    struct UninstallView: View {
        @Binding var isPresented: Bool
        @Binding var game: String
        
        var body: some View {
            NotImplemented()
            
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
        }
    }
}


#Preview {
    LibraryView()
}
