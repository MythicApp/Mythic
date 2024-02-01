//
//  BottleCreation.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/1/2024.
//

import SwiftUI

struct BottleCreationView: View {
    @Binding var isPresented: Bool
    
    @State private var bottleName: String = "My Bottle"
    @State private var bottlePath: URL = Wine.bottlesDirectory!
    
    @State private var isBooting: Bool = false
    
    @State private var bootErrorDescription: String = "Unknown error."
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
                            case .success(_): // swiftlint:disable:this empty_enum_arguments
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
