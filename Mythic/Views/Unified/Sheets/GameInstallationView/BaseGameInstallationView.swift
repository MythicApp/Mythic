//
//  BaseGameInstallationView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 28/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

struct BaseGameInstallationView<Content>: View where Content: View {
    @Binding var game: Game
    @Binding var isPresented: Bool
    @Binding var isImageEmpty: Bool
    var type: String
    @Binding var operating: Bool
    var action: () async throws -> Void

    @ViewBuilder var content: () -> Content
    
    @State private var isActionSuccessful: Bool?

    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            HStack {
                GameImageCard(url: game.verticalImageURL, isImageEmpty: .constant(false))
                    .aspectRatio(3/4, contentMode: .fit)
                

                VStack {
                    Text("\(type) \(game.description)")
                        .font(.title)
                        .bold()

                    if let storefront = game.storefront {
                        SubscriptedTextView(storefront.description)
                    }

                    content()
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }

                Spacer()

                OperationButton(type,
                                operating: $operating,
                                successful: $isActionSuccessful) {
                    do {
                        try await action()
                    } catch {
                        isActionSuccessful = false
                    }
                    
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        
    }
}

#Preview {
    BaseGameInstallationView(
        game: .constant(placeholderGame(type: Game.self)), isPresented: .constant(true),
        isImageEmpty: .constant(false),
        type: "Install",
        operating: .constant(false),
        action: { print("action!") },
        content: {
            Form {
                Text("Content goes here!!!")
            }
            .formStyle(.grouped)
        }
    )
    .padding()
}
