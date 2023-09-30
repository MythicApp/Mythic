//
//  GameUninstall.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

extension GameListView {
    struct UninstallView: View {
        @Binding var isPresented: Bool
        @Binding var game: String
        
        @State private var keepFiles: Bool = false
        @State private var skipUninstaller: Bool = false
        
        @State private var isConfirmationPresented = false
        
        var body: some View {
            VStack {
                Text("Uninstall \(game)")
                    .font(.title)
                
                Spacer()
                
                HStack {
                    Toggle(isOn: $keepFiles) {
                        Text("Keep files")
                    }
                    Spacer()
                }
                
                HStack {
                    Toggle(isOn: $skipUninstaller) {
                        Text("Don't run uninstaller")
                    }
                    Spacer()
                }
                
                HStack {
                    Button("Cancel", role: .cancel) {
                        isPresented.toggle()
                    }
                    
                    Spacer()
                    
                    Button("Uninstall") {
                        isConfirmationPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .alert(isPresented: $isConfirmationPresented) {
                    Alert(
                        title: Text("Are you sure you want to delete \(game)?"),
                        primaryButton: .destructive(Text("Delete")) {
                            _ = Legendary.command(
                                args: [
                                    "-y",
                                    "uninstall",
                                    keepFiles ? "--keep-files" : nil,
                                    skipUninstaller ? "--skip-uninstaller" : nil,
                                    game
                                ]
                                    .compactMap { $0 },
                                useCache: false
                            )
                            
                            isConfirmationPresented = false
                            isPresented = false
                        },
                        secondaryButton: .cancel(Text("Cancel")) {
                            isConfirmationPresented = false
                        }
                    )
                }
            }
            .padding()
        }
    }
}


#Preview {
    LibraryView()
}
