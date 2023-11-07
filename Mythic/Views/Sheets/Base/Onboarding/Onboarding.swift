//
//  Onboarding.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/9/2023.
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Binding var isFirstLaunch: Bool
    
    @Binding var isInstallViewPresented: Bool
    
    @State private var isAuthViewPresented = false
    @State private var authSuccessful: Bool? = nil
    
    var body: some View {
        VStack {
            Text("Hey there!")
                .font(.title)
            
            Divider()
            
            Text("Welcome to Mythic. To get started, sign in to epic games."
                + "\nOtherwise, just click next."
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
