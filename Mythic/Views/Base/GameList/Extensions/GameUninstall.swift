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
        @State private var isProgressViewSheetPresented = false
        @State private var isErrorPresented = false
        
        @State private var errorContent: Substring = ""
        
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
            }
            .padding()
            
            .sheet(isPresented: $isProgressViewSheetPresented) {
                ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
            }
            
            .alert(isPresented: $isErrorPresented) {
                Alert(
                    title: Text("Error uninstalling game"),
                    message: Text(errorContent)/*,
                                                dismissButton: .default(Text("Got it!"))*/
                )
            }
            
            .alert(isPresented: $isConfirmationPresented) {
                Alert(
                    title: Text("Are you sure you want to delete \(game)?"),
                    primaryButton: .destructive(Text("Delete")) {
                        isProgressViewSheetPresented = true
                        
                        DispatchQueue.global(qos: .userInteractive).async { [self] in
                            let commandOutput = Legendary.command(
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
                            
                            if let commandStderrString = String(data: commandOutput.stderr, encoding: .utf8) {
                                if !commandStderrString.isEmpty {
                                    if commandStderrString.contains("INFO: Game has been uninstalled.") {
                                        isProgressViewSheetPresented = false
                                        isPresented = false
                                    }
                                }
                                
                                for line in commandStderrString.components(separatedBy: "\n") {
                                    if line.contains("ERROR:") {
                                        if let range = line.range(of: "ERROR: ") {
                                            let substring = line[range.upperBound...]
                                            errorContent = substring
                                            isProgressViewSheetPresented = false
                                            isErrorPresented = true
                                            break // first error only
                                        }
                                    }
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel(Text("Cancel")) {
                        isConfirmationPresented = false
                    }
                )
            }

        }
    }
}


#Preview {
    LibraryView()
}
