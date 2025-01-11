//
//  Auth.swift
//  Mythic
//
// MARK: - Copyright
// Copyright © 2024 vapidinfinity

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

// MARK: - AuthView Struct
/// SwiftUI view for authentication with Epic Games.
struct AuthView: View {
    // FIXME: oh god refactor
    
    // MARK: - Binding Properties
    @Binding var isPresented: Bool
    @Binding var authSuccessful: Bool?
    
    // MARK: - State Properties
    @State private var code: String = .init()
    @State private var isLoggingIn: Bool = false
    @State private var progressViewPresented: Bool = false
    @State private var isProgressViewSheetPresented: Bool = false
    @State private var isHelpPopoverPresented: Bool = false
    @State private var isError: Bool = false
    
    // MARK: - Submit to Legendary
    /// Submits the authorization code to Legendary for authentication.
    func submitToLegendary() async {
        if !code.isEmpty {
            isLoggingIn = true
            progressViewPresented = true
            
            func displayError() {
                authSuccessful = false
                isError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    code = .init()
                    progressViewPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 /* Just to be safe */) {
                        isError = false
                    }
                }
            }
            
            do {
                try await Legendary.command(arguments: ["auth", "--code", code], identifier: "signin") { output in
                    if output.stderr.contains("ERROR: Login attempt failed") {
                        displayError(); return
                    }
                }
                
                authSuccessful = true
                $isPresented.wrappedValue = false
                progressViewPresented = false
            } catch {
                displayError()
            }
        }
    }
    
    init(isPresented: Binding<Bool>, authSuccessful: Binding<Bool?> = .constant(false)) {
        _isPresented = isPresented
        _authSuccessful = authSuccessful
    }
    
    // MARK: - Body
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
                SecureField("Enter authorisation key...", text: $code)
                    .onSubmit {
                        Task(priority: .userInitiated) { await submitToLegendary() }
                    }
                    .frame(width: 350, alignment: .center)
                
                Button {
                    Task(priority: .userInitiated) { await submitToLegendary() }
                } label: {
                    Text("Submit")
                }
                .buttonStyle(.borderedProminent)
            }
            .fixedSize()
            
            HStack {
                Button(action: { // TODO: implement question mark popover
                    isHelpPopoverPresented.toggle()
                }, label: {
                    Image(systemName: "questionmark")
                        .controlSize(.small)
                })
                .clipShape(.circle)
                .popover(isPresented: $isHelpPopoverPresented) {
                    VStack {
                        NotImplementedView()
                    }
                    .padding()
                }
                
                Spacer()
            }
            /*
            .sheet(isPresented: $progressViewPresented) {
                ProgressViewSheetWithError(isError: $isError, isPresented: $isProgressViewSheetPresented)
            }
             */
        }
        .padding()
        .fixedSize()
        .task(priority: .userInitiated) { workspace.open(URL(string: "http://legendary.gl/epiclogin")!) }
    }
}

// MARK: - Preview
#Preview {
    AuthView(
        isPresented: .constant(true),
        authSuccessful: .constant(nil)
    )
}
