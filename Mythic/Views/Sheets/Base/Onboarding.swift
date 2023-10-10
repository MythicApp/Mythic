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
    
    @State private var isAuthViewPresented = false
    @State private var authSuccessful: Bool = false
    
    var body: some View {
        VStack {
            Text("Hey there!")
                .font(.title)
            
            Divider()
            
            Text("Welcome to Mythic. To get started, sign in to epic games.")
            
            HStack {
                Button("Close") {
                    isPresented = false
                    isFirstLaunch = false
                }
                
                Button("Sign In") {
                    NSWorkspace.shared.open(URL(string: "http://legendary.gl/epiclogin")!)
                    isAuthViewPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        
        .sheet(isPresented: $isAuthViewPresented) {
            AuthView(isPresented: $isAuthViewPresented, authSuccessful: $authSuccessful)
        }
        
        .onReceive(Just(authSuccessful)) { success in
            if success {
                isPresented = false
            }
        }
    }
}

#Preview {
    MainView()
}
