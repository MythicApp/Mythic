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
        @Binding var isGameListRefreshCalled: Bool
        
        @State private var keepFiles: Bool = false
        @State private var skipUninstaller: Bool = false
        
        @State private var isErrorPresented = false
        @State private var isConfirmationPresented = false
        @State private var isProgressViewSheetPresented = false
        
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
                        isPresented = false
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
            
            .alert(isPresented: $isErrorPresented) { // not working...
                Alert(
                    title: Text("Error uninstalling game"),
                    message: Text(errorContent)
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
                                        isGameListRefreshCalled = true
                                    }
                                }
                                
                                for line in commandStderrString.components(separatedBy: "\n") {
                                    print("line \(line)")
                                    if line.contains("ERROR:") {
                                        print("line \(line)")
                                        if let range = line.range(of: "ERROR: ") {
                                            print("range \(line)")
                                            let substring = line[range.upperBound...]
                                            print("substring \(substring)")
                                            errorContent = substring
                                            isProgressViewSheetPresented = false
                                            isErrorPresented = true // only one alert works for some reason (definitely a bug)
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
