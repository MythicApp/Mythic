//
//  GameUninstall.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI
import OSLog

extension GameListView {
    struct UninstallView: View {
        @Binding var isPresented: Bool
        @Binding var game: Legendary.Game
        @Binding var isGameListRefreshCalled: Bool
        
        enum ActiveAlert {
            case error, confirmation
        }
        
        @State private var keepFiles: Bool = false
        @State private var skipUninstaller: Bool = false
        
        @State private var isProgressViewSheetPresented = false
        
        @State private var isAlertPresented = false
        @State private var activeAlert: ActiveAlert = .confirmation
        
        @State private var errorContent: Substring = ""
        
        var body: some View {
            VStack {
                Text("Uninstall \(game.title)")
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
                        activeAlert = .confirmation
                        isAlertPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            .sheet(isPresented: $isProgressViewSheetPresented) {
                ProgressViewSheet(isPresented: $isProgressViewSheetPresented)
            }
            
            .alert(isPresented: $isAlertPresented) {
                switch activeAlert {
                case .error:
                    Alert(
                        title: Text("Error uninstalling game"),
                        message: Text(errorContent)
                    )
                case .confirmation:
                    Alert(
                        title: Text("Are you sure you want to uninstall \(game.title)?"),
                        primaryButton: .destructive(Text("Uninstall")) {
                            isProgressViewSheetPresented = true
                            
                            Task {
                                let commandOutput = await Legendary.command(
                                    args: [
                                        "-y",
                                        "uninstall",
                                        keepFiles ? "--keep-files" : nil,
                                        skipUninstaller ? "--skip-uninstaller" : nil,
                                        game.appName
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
                                        if line.contains("ERROR:") {
                                            if let range = line.range(of: "ERROR: ") {
                                                let substring = line[range.upperBound...]
                                                errorContent = substring
                                                isProgressViewSheetPresented = false
                                                activeAlert = .error
                                                isAlertPresented = true
                                                Logger.app.error("Uninstall error: \(errorContent)")
                                                break // first error only
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        secondaryButton: .cancel(Text("Cancel")) {
                            isAlertPresented = false
                        }
                    )
                }
            }
        }
    }
}


#Preview {
    LibraryView()
}
