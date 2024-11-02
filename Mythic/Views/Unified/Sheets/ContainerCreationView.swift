//
//  ContainerCreation.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/1/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import SwiftUI
import SwordRPC

struct ContainerCreationView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var variables: VariableManager = .shared

    @State private var containerName: String = "My Container"
    @State private var containerURL: URL = Wine.containersDirectory!
    
    @State private var isBooting: Bool = false
    @State private var isCancellationAlertPresented: Bool = false
    
    @State private var bootErrorDescription: String = "Unknown Error."
    @State private var isBootFailureAlertPresented: Bool = false
    
    var body: some View {
        VStack {
            Text("Create a container")
                .font(.title)
                .padding([.horizontal, .top])

            Form {
                TextField("Choose a name for your container:", text: $containerName)
                
                HStack {
                    VStack {
                        HStack {
                            Text("Where do you want the container's base path to be located?")
                            Spacer()
                        }
                        HStack {
                            Text(containerURL.prettyPath())
                                .foregroundStyle(.placeholder)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !FileLocations.isWritableFolder(url: containerURL) {
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
                            containerURL = openPanel.urls.first!
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
                        title: .init("Are you sure you want to cancel container creation?"),
                        message: .init("This will cancel \"\(containerName)\"'s creation."),
                        primaryButton: .destructive(.init("OK")),
                        secondaryButton: .cancel()
                    )
                }
                
                Spacer()

                if isBooting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(0.5)
                }

                Button("Done") {
                    Task(priority: .userInitiated) {
                        withAnimation { isBooting = true }
                        await Wine.boot(baseURL: containerURL, name: containerName) { result in
                            switch result {
                            case .success:
                                withAnimation { isBooting = false }
                                isPresented = false
                            case .failure(let error):
                                bootErrorDescription = error.localizedDescription
                                withAnimation { isBooting = false }
                                isBootFailureAlertPresented = true
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBooting)
                .disabled(!FileLocations.isWritableFolder(url: containerURL))
                .disabled((Wine.containerURLs.first(where: { $0.lastPathComponent == containerName}) != nil))
            }
            .padding()
        }
        
        .alert(isPresented: $isBootFailureAlertPresented) {
            Alert(
                title: .init("Failed to boot \"\(containerName)\"."),
                message: .init(bootErrorDescription)
            )
        }
        
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Currently creating container \"\(containerName)\""
                presence.state = "Creating a container"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
    }
}

#Preview {
    ContainerCreationView(isPresented: .constant(true))
}
