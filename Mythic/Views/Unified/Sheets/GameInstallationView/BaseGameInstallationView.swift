//
//  BaseGameInstallationView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 28/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

@available(*, deprecated, message: "Not for use yet ❤️")
struct BaseGameInstallationView<Content>: View where Content: View {
    @Binding var isPresented: Bool
    @Binding var game: Game
    @Binding var isImageEmpty: Bool
    var titleText: Text
    @Binding var operating: Bool
    var action: () async -> Void

    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack { // wrap in VStack to prevent padding from callers being applied within the view
            HStack {
                GameCard.ImageCard(game: $game,
                                   isImageEmpty: .constant(false))

                VStack {
                    titleText
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

                OperationButton("Done",
                                operating: $operating,
                                successful: .constant(nil),
                                action: { await action(); isPresented = false })
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .navigationTitle(titleText)
    }
}

#Preview {
    BaseGameInstallationView(
        isPresented: .constant(true),
        game: .constant(placeholderGame(type: Game.self)),
        isImageEmpty: .constant(false),
        titleText: Text("Install (game)"),
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
