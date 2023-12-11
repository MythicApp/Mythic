//
//  Auth.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.


import SwiftUI

struct AuthView: View {
    @Binding var isPresented: Bool
    @Binding var authSuccessful: Bool?
    
    @State private var code: String = String()
    @State private var isLoggingIn: Bool = false
    @State private var progressViewPresented = false
    @State private var isProgressViewSheetPresented = false
    @State private var isError = false
    
    func submitToLegendary() async {
        if !code.isEmpty {
            isLoggingIn = true
            progressViewPresented = true
            
            let command = await Legendary.command(args: ["auth", "--code", code], useCache: false, identifier: "signIn")
            
            if let commandStderrString = String(data: command.stderr, encoding: .utf8), commandStderrString.contains("Successfully logged in as") {
                authSuccessful = true
                $isPresented.wrappedValue = false
                progressViewPresented = false
            } else {
                authSuccessful = false
                isError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    code = String()
                    progressViewPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 /* Just to be safe */) {
                        isError = false
                    }
                }
            }
        }
    }
    
    init(isPresented: Binding<Bool>, authSuccessful: Binding<Bool?> = .constant(false)) {
        _isPresented = isPresented
        _authSuccessful = authSuccessful
    }
    
    var body: some View {
        VStack {
            Text("Sign in to Epic Games")
                .font(.title)
            
            Divider()
            
            HStack {
                Text("A link should've opened in your browser. If not, click")
                Link("here.", destination: URL(string: "https://legendary.gl/epiclogin")!)
            }
            
            Text("\nEnter the 'authorisationCode' from the JSON response in the field below.")
            
            HStack {
                TextField("Enter authorisation key...", text: $code)
                    .onSubmit {
                        Task { await submitToLegendary() }
                    }
                    .frame(width: 350, alignment: .center)
                
                Button {
                    Task { await submitToLegendary() }
                } label: {
                    Text("Submit")
                }
                .buttonStyle(.borderedProminent)
            }
            .fixedSize()
            
            .sheet(isPresented: $progressViewPresented) {
                ProgressViewSheetWithError(isError: $isError, isPresented: $isProgressViewSheetPresented)
            }
        }
        .padding()
        .fixedSize()
    }
}

#Preview {
    AuthView(
        isPresented: .constant(true),
        authSuccessful: .constant(nil)
    )
}
