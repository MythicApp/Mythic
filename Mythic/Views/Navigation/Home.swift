//
//  Home.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 12/9/2023.
//

import SwiftUI
import Cocoa

struct HomeView: View {
    
    @State private var signedIn: Bool = true
    
    @State private var isProgressViewSheetPresented: Bool = true
    @State private var isAuthViewPresented = false
    
    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(URL(string: "http://legendary.gl/epiclogin")!)
            isAuthViewPresented = true
        }) {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.accentColor)
                Text("Sign In")
            }
        }
        .opacity(signedIn ? 0 : 1)
        
        
        .onAppear {
            DispatchQueue.global().async {
                let checkIfSignedIn = Legendary.signedIn(useCache: true)
                DispatchQueue.main.async {
                    signedIn = checkIfSignedIn
                    isProgressViewSheetPresented = false
                }
            }
        }
        
        .sheet(isPresented: $isProgressViewSheetPresented) {
            ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
        }
        
        .sheet(isPresented: $isAuthViewPresented) {
            AuthView(isPresented: $isAuthViewPresented)
        }
    }
}

#Preview {
    HomeView()
}
