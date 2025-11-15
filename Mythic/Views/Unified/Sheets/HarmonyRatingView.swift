//
//  HarmonyRatingView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 16/1/2025.
//

import Foundation
import SwiftUI

struct HarmonyRatingView: View {
    @Binding var isPresented: Bool
    @Binding var game: Game

    @State private var rating: Game.Compatibility?
    @State private var hoveringOverIndex: Int = 0

    @State private var isConfirmationPresented: Bool = false

    @State private var isUploading: Bool = false

    func uploadCompatibilityData() {
        withAnimation { isUploading = true }

        // TODO: handle upload w/ UUID of Mythic spam protection and whatnot

        // TODO: if success
        isPresented = false
    }

    var body: some View {
            VStack {
                Text("How well did \"\(game.title)\" run?")
                    .font(.title)
                
                Text("This will be uploaded to Harmony, Mythic's game compatibility database.")
                    .foregroundStyle(.placeholder)
            }
            .padding()
            .fixedSize()

            StarRatingView(
                rating: .init(
                    get: { rating.flatMap { Game.Compatibility.allCases.firstIndex(of: $0).map { $0 + 1 } } ?? 0 },
                    set: { rating = Game.Compatibility.allCases[$0 - 1] }
                ),
                hoveringOverIndex: $hoveringOverIndex
            )

            Form {
                if hoveringOverIndex > 0 {
                    Text(Game.Compatibility.allCases[hoveringOverIndex - 1].rawValue)
                } else {
                    Text("Please choose a rating.")
                }
            }
            .formStyle(.grouped)
            .lineLimit(2, reservesSpace: true)
            .scrollDisabled(true)
            .scrollIndicators(.hidden)

            HStack {
                Button("Cancel", role: .cancel) {
                    isConfirmationPresented = true
                }
                .alert(isPresented: $isConfirmationPresented) {
                    Alert(
                        title: .init("Are you sure you want to proceed without rating?"),
                        message: .init("Harmony ratings help every Mythic user understand how well a game runs."),
                        primaryButton: .cancel(),
                        secondaryButton: .default(.init("OK")) {
                            isPresented = false
                        }
                    )
                }

                Spacer()

                HStack {
                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(0.5)
                    }

                    Button("Done") {
                        uploadCompatibilityData()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(rating == nil)
                }
            }
            .padding([.horizontal, .bottom])
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            HarmonyRatingView(
                isPresented: .constant(true),
                game: .constant(placeholderGame(forSource: .local)))
        }
}
