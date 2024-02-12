//
//  BottleCreation.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/1/2024.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI

struct BottleCreationView: View {
    @Binding var isPresented: Bool
    
    @State private var bottleName: String = "My Bottle"
    @State private var bottlePath: URL = Wine.bottlesDirectory!
    
    @State private var isBooting: Bool = false
    
    @State private var bootErrorDescription: String = "Unknown Error."
    @State private var isBootFailureAlertPresented: Bool = false
    
    var body: some View {
        VStack {
            Text("Create a bottle")
                .font(.title)
            
            Form {
                TextField("Choose a name for your bottle:", text: $bottleName)
                
                HStack {
                    VStack {
                        HStack { // FIXME: jank
                            Text("Where do you want the bottle's base path to be located?")
                            Spacer()
                        }
                        HStack {
                            Text(bottlePath.prettyPath())
                                .foregroundStyle(.placeholder)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !FileLocations.isWritableFolder(url: URL(filePath: bottlePath.path(percentEncoded: false))) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .help("Folder is not writable.")
                    }
                    
                    Button("Browse...") {
                        let openPanel = NSOpenPanel()
                        openPanel.canChooseDirectories = true
                        openPanel.canChooseFiles = false
                        openPanel.canCreateDirectories = true
                        openPanel.allowsMultipleSelection = false
                        
                        if openPanel.runModal() == .OK {
                            bottlePath = openPanel.urls.first!
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .disabled(isBooting) // FIXME: replace with confirmation alert if isBooting
                
                Spacer()
                
                ProgressView()
                    .controlSize(.small)
                    .padding(0.5)
                    .opacity(isBooting ? 1 : 0)
                
                Button("Done") {
                    Task(priority: .userInitiated) {
                        isBooting = true
                        await Wine.boot(baseURL: bottlePath, name: bottleName) { result in
                            switch result {
                            case .success:
                                isBooting = false
                                isPresented = false
                            case .failure(let error):
                                bootErrorDescription = error.localizedDescription
                                isBooting = false
                                isBootFailureAlertPresented = true
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBooting)
                .disabled(!FileLocations.isWritableFolder(url: bottlePath))
            }
        }
        .padding()
        .alert(isPresented: $isBootFailureAlertPresented) {
            Alert(
                title: .init("Failed to boot \"\(bottleName).\""),
                message: .init(bootErrorDescription)
            )
        }
    }
}

#Preview {
    BottleCreationView(isPresented: .constant(true))
}
