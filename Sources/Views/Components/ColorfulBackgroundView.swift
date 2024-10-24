//
//  ColorfulBackgroundView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/23/24.
//

import SwiftUI
import ColorfulX

struct ColorfulBackgroundView: View {
    private let animationColors: [Color] = [
        .init(hex: "#5412F6"),
        .init(hex: "#7E1ED8"),
        .init(hex: "#2c1280")
    ]
    private let animationSpeed = 0.5
    private let animationNoise: Double = 0.2

    var body: some View {
        ColorfulView(color: .constant(animationColors), speed: .constant(animationSpeed), noise: .constant(animationNoise))
            .ignoresSafeArea()
    }
}

#Preview {
    ColorfulBackgroundView()
}
