//
//  UninstallGame.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 6/3/2024.
//

import SwiftUI
import OSLog

struct UninstallViewEvo: View {
    @Binding var game: Game
    @Binding var isPresented: Bool
    
    @State private var keepFiles: Bool = false
    @State private var skipUninstaller: Bool = false
    @State private var isConfirmationPresented: Bool = false
    
    @State var uninstalling: Bool = false
    
    @State private var isUninstallationErrorPresented: Bool = false
    @State private var uninstallationErrorReason: String?
    
    var body: some View {
        VStack {
            Text("Uninstall \"\(game.title)\"")
                .font(.title)
            
            Form {
                HStack {
                    Toggle(isOn: $keepFiles) {
                        Text("Don't delete the game files (Delete it from Mythic only)")
                    }
                    Spacer()
                }
                
                HStack {
                    Toggle(isOn: $skipUninstaller) {
                        Text("Don't run uninstaller (If applicable)")
                    }
                    Spacer()
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .disabled(uninstalling)
                
                Spacer()
                    .alert(isPresented: $isUninstallationErrorPresented) {
                        Alert(
                            title: .init("Unable to uninstall \"\(game.title)\"."),
                            message: .init(uninstallationErrorReason ?? "Unknown Error.")
                        )
                    }
                HStack {
                    if uninstalling {
                        ProgressView()
                            .controlSize(.small)
                            .padding(0.5)
                    }
                    Button("Uninstall") {
                        isConfirmationPresented = true
                    }
                    .disabled(uninstalling)
                }
                .buttonStyle(.borderedProminent)
                .alert(isPresented: $isConfirmationPresented) {
                    Alert(
                        title: Text("Are you sure you want to uninstall \"\(game.title)\"?"),
                        primaryButton: .destructive(Text("Uninstall")) {
                            Task(priority: .userInitiated) {
                                uninstalling = true
                                
                                let output = await Legendary.command(
                                    args: [
                                        "-y", "uninstall",
                                        keepFiles ? "--keep-files" : nil,
                                        skipUninstaller ? "--skip-uninstaller" : nil,
                                        game.id
                                    ] .compactMap { $0 },
                                    useCache: false,
                                    identifier: "uninstall"
                                )
                                
                                if let stderrString = String(data: output.stderr, encoding: .utf8),
                                   // swiftlint:disable:next force_try
                                   let errorLine = stderrString.split(separator: "\n").first(where: { $0.contains("ERROR:") })?.trimmingPrefix(try! Regex(#"\[(.*?)\]"#)) {
                                    // Dirtyfix for OSError(66, 'Directory not empty') and other legendary game deletion failures
                                    guard !errorLine.contains("OSError(66, 'Directory not empty')") || !errorLine.contains("please remove manually") else {
                                        if let gamePath = game.path { try? files.removeItem(atPath: gamePath) }
                                        return
                                    }
                                    
                                    uninstallationErrorReason = errorLine.replacingOccurrences(of: "ERROR: ", with: "")
                                    isUninstallationErrorPresented = true
                                } else {
                                    isPresented = false
                                }
                                
                                uninstalling = false
                            }
                        },
                        secondaryButton: .cancel(Text("Cancel")) {
                            isConfirmationPresented = false
                        }
                    )
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    UninstallViewEvo(game: .constant(placeholderGame(type: .local)), isPresented: .constant(true))
}
