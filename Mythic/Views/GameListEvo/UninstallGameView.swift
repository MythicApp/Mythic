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
                    .disabled(game.type == .local)
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
                            switch game.type {
                            case .epic:
                                Task(priority: .userInitiated) {
                                    uninstalling = true
                                    do {
                                        try await Legendary.command(arguments: [
                                            "-y", "uninstall",
                                            keepFiles ? "--keep-files" : nil,
                                            skipUninstaller ? "--skip-uninstaller" : nil,
                                            game.id
                                        ] .compactMap { $0 }, identifier: "uninstall") { output in
                                            guard output.stderr.contains("ERROR:") else { return }
                                            let errorLine = output.stderr.trimmingPrefix(try! Regex(#"\[(.*?)\]"#)).trimmingPrefix("ERROR: ")
                                            // swiftlint:disable:previous force_try
                                            guard !errorLine.contains("OSError(66, 'Directory not empty')") || !errorLine.contains("please remove manually") else {
                                                if let gamePath = game.path { try? files.removeItem(atPath: gamePath) }
                                                return
                                            }
                                            
                                            uninstallationErrorReason = String(errorLine)
                                            isUninstallationErrorPresented = true
                                        }
                                    } catch {
                                        uninstallationErrorReason = error.localizedDescription
                                        isUninstallationErrorPresented = true
                                    }
                                    
                                    uninstalling = false
                                }
                            case .local:
                                do {
                                    guard let gamePath = game.path else { throw FileLocations.FileDoesNotExistError(.init(filePath: game.path ?? .init())) }
                                    if !keepFiles { try files.removeItem(atPath: gamePath) }
                                    LocalGames.library?.remove(game)
                                    isPresented = false
                                } catch {
                                    uninstallationErrorReason = error.localizedDescription
                                    isUninstallationErrorPresented = true
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
        .interactiveDismissDisabled()
    }
}

#Preview {
    UninstallViewEvo(game: .constant(.init(type: .local, title: .init())), isPresented: .constant(true))
}
