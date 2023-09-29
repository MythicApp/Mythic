//
//  Auth.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

struct AuthView: View {
    @Binding var isPresented: Bool
    
    @State private var code: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var progressViewPresented = false
    @State private var isProgressViewSheetPresented = false
    @State private var isError = false
    
    func submitToLegendary() {
        if !code.isEmpty {
            isLoggingIn = true
            progressViewPresented = true
            
            let cmd = Legendary.command(args: ["auth", "--code", code], useCache: false)
            if cmd.stderr.string.contains("Successfully logged in as") {
                $isPresented.wrappedValue = false
                progressViewPresented = false
            } else {
                isError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    code = ""
                    progressViewPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 /* Just to be safe */) {
                        isError = false
                    }
                }
            }
        }
    }
    
    var body: some View {
        HStack {
            TextField("Enter auth key...", text: $code)
                .onSubmit {
                    submitToLegendary()
                }
                .frame(width: 350, alignment: .center)
            
            Button(action:{
                submitToLegendary()
            }) {
                Text("Submit")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .fixedSize()
        
        .sheet(isPresented: $progressViewPresented) {
            ProgressViewSheetWithError(isError: $isError, isPresented: $isProgressViewSheetPresented)
        }
    }
}

#Preview {
    HomeView()
}
