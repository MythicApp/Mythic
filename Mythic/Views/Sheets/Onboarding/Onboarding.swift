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
            Text("Welcome to Mythic!")
                .font(.title)
            
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
                if Libraries.isInstalled() == true {
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
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        
        // MARK: - Other Properties
        
        .sheet(isPresented: $isAuthViewPresented) {
            AuthView(isPresented: $isAuthViewPresented, authSuccessful: $authSuccessful)
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(
        isPresented: .constant(true),
        isInstallViewPresented: .constant(false)
    )
}
