//
//  Onboarding.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI
import Combine

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Binding var isFirstLaunch: Bool
    
    @Binding var isInstallViewPresented: Bool
    
    @State private var isAuthViewPresented = false
    @State private var authSuccessful: Bool?
    
    var body: some View {
        VStack {
            Text("Welcome to Mythic!")
                .font(.title)
            
            Divider()
            
            Text("Let's get started by signing in to Epic Games."
                 + "\nIf you do not want to use Epic Games, just click next."
            )
            .multilineTextAlignment(.center)
            
            HStack {
                if Libraries.isInstalled() == true {
                    Button("Close") {
                        isPresented = false
                        isFirstLaunch = false
                    }
                }
                
                if Legendary.signedIn() == false && authSuccessful != true {
                    Button("Sign In") {
                        NSWorkspace.shared.open(URL(string: "http://legendary.gl/epiclogin")!)
                        isAuthViewPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Next") {
                    isPresented = false
                    isInstallViewPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        
        .sheet(isPresented: $isAuthViewPresented) {
            AuthView(isPresented: $isAuthViewPresented, authSuccessful: $authSuccessful)
        }
        
        /*
         .onReceive(Just(authSuccessful)) { success in
         if success {
         isPresented = false
         isFirstLaunch = false
         }
         }
         */
    }
}

#Preview {
    OnboardingView(
        isPresented: .constant(true),
        isFirstLaunch: .constant(true),
        isInstallViewPresented: .constant(false)
    )
}
