//
//  Onboarding.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import Combine

// Add hex support for gradient overlay for "Mythic" text.
extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - OnboardingView Struct
/// A view providing onboarding experience for first-time users.
struct OnboardingView: View {
    // MARK: - Binding Variables
    @Binding var isPresented: Bool
    @Binding var isInstallViewPresented: Bool
    
    // MARK: - State Variables
    @State private var isAuthViewPresented = false
    @State private var authSuccessful: Bool?
    // MARK: - Body
    var body: some View {
        VStack {
            Text("Welcome to ")
                .font(.title)
            
            Text("Mythic!")
                .font(.title)
                .overlay(gradientOverlay)
            
            Divider()
            
            Text(
                """
                Let's get started by signing in to Epic Games.
                If you do not want to use Epic Games, just click next.
                """
            )
            .multilineTextAlignment(.center)
            
            // MARK: - Action Buttons
            HStack {
                // MARK: Close Button
                if Libraries.isInstalled() {
                    Button("Close") {
                        isPresented = false
                    }
                }
                
                // MARK: Sign In Button
                if Legendary.signedIn() == false && authSuccessful != true {
                    Button("Sign In") {
                        NSWorkspace.shared.open(URL(string: "http://legendary.gl/epiclogin")!)
                        isAuthViewPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // MARK: Next Button
                Button("Next") {
                    isPresented = false
                    isInstallViewPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        
        // MARK: - Other Properties
        
        .sheet(isPresented: $isAuthViewPresented) {
            AuthView(isPresented: $isAuthViewPresented, authSuccessful: $authSuccessful)
        }
    }
    
    // MARK: - Gradient Overlay
    var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(NSColor(hex: "#7e0cef")!),
                Color(NSColor(hex: "#8b01dda")!)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Text("Mythic!").font(.title))
    }
}

// MARK: - Preview
    #Preview {
    OnboardingView(
        isPresented: .constant(true),
        isInstallViewPresented: .constant(false)
    )
}
