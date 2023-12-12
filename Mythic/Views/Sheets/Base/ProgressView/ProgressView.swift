//
//  ProgressView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/9/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

import SwiftUI

// MARK: - ProgressViewSheet Struct
/// A view displaying a progress indicator that may include a timeout warning.
struct ProgressViewSheet: View {
    // MARK: - Binding Variables
    @Binding var isPresented: Bool
    
    // MARK: - State Variables
    @State private var timeoutWarning = false
    @State private var dismissableWithEsc = false
    
    // MARK: - Body
    var body: some View {
        VStack {
            // MARK: ProgressView
            ProgressView()
                .padding()
                .interactiveDismissDisabled(!dismissableWithEsc)
            
            // MARK: Timeout Warning
            if timeoutWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.large)
                    
                    Text("It seems loading's taking a while.")
                }
                .padding()
                
                HStack {
                    // MARK: Dismiss Button
                    Button {
                        isPresented = false
                    } label: {
                        Text("Dismiss loading")
                    }
                    
                    // MARK: Keep Waiting Button
                    Button {
                        timeoutWarning = false
                        dismissableWithEsc = true
                    } label: {
                        Text("Keep waiting (dismissable with esc)")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .fixedSize()
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
                timeoutWarning = true
            }
        }
    }
}
