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
import SwordRPC

struct BottleCreationView: View {
    @Binding var isPresented: Bool
    
    @State private var bottleName: String = "My Bottle"
    @State private var bottleURL: URL = Wine.bottlesDirectory!
    
    @State private var isBooting: Bool = false
    @State private var isCancellationAlertPresented: Bool = false
    
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
                        HStack {
                            Text("Where do you want the bottle's base path to be located?")
                            Spacer()
                        }
                        HStack {
                            Text(bottleURL.prettyPath())
                                .foregroundStyle(.placeholder)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !FileLocations.isWritableFolder(url: bottleURL) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .help("Folder is not writable.")
                    }
                    
                    Button("Browse...") { // TODO: replace with .fileImporter
                        let openPanel = NSOpenPanel()
                        openPanel.canChooseDirectories = true
                        openPanel.canChooseFiles = false
                        openPanel.canCreateDirectories = true
                        openPanel.allowsMultipleSelection = false
                        
                        if openPanel.runModal() == .OK {
                            bottleURL = openPanel.urls.first!
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    if isBooting {
                        isCancellationAlertPresented = true
                    } else {
                        isPresented = false
                    }
                }
                .alert(isPresented: $isCancellationAlertPresented) {
                    Alert(
                        title: .init("Are you sure you want to cancel bottle creation?"),
                        message: .init("This will cancel \"\(bottleName)\"'s creation."),
                        primaryButton: .destructive(.init("OK")),
                        secondaryButton: .cancel()
                    )
                }
                
                Spacer()
                
                ProgressView()
                    .controlSize(.small)
                    .padding(0.5)
                    .opacity(isBooting ? 1 : 0)
                
                Button("Done") {
                    Task(priority: .userInitiated) {
                        isBooting = true
                        await Wine.boot(baseURL: bottleURL, name: bottleName) { result in
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
                .disabled(!FileLocations.isWritableFolder(url: bottleURL))
            }
        }
        .padding()
        
        .alert(isPresented: $isBootFailureAlertPresented) {
            Alert(
                title: .init("Failed to boot \"\(bottleName).\""),
                message: .init(bootErrorDescription)
            )
        }
        
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Currently creating bottle \"\(bottleName)\""
                presence.state = "Creating a bottle"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
    }
}

#Preview {
    BottleCreationView(isPresented: .constant(true))
}
